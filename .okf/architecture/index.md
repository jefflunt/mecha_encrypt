---
type: Technical Specification
title: MechaEncrypt Architecture & Three-Pillar Auditing Pipeline
schema_version: "0.2"
sources:
  - ref: "lib/mecha_encrypt.rb"
    type: source_code
  - ref: "lib/mecha_encrypt/configuration.rb"
    type: source_code
  - ref: "lib/mecha_encrypt/registry.rb"
    type: source_code
  - ref: "lib/mecha_encrypt/auditor/static.rb"
    type: source_code
  - ref: "lib/mecha_encrypt/auditor/prober.rb"
    type: source_code
  - ref: "lib/mecha_encrypt/matrix_test.rb"
    type: source_code
  - ref: "lib/tasks/mecha_encrypt.rake"
    type: source_code
verified: machine-confirmed
last_modified: "2026-10-15"
---

# MechaEncrypt Architecture & Three-Pillar Auditing Pipeline

## 1. Design Philosophy: Closed-by-Default Column Encryption

Rails' built-in `ActiveRecord::Encryption` (`encrypts :column_name`) is opt-in per model attribute. When new migrations add tables or columns, nothing prevents sensitive columns from being stored in plaintext or accidentally indexed with non-deterministic IVs.

`mecha_encrypt` enforces **closed-by-default schema encryption parity** using three coordinated components:
1. **Central Registry (`config/mecha_encrypt.yml` & `MechaEncrypt::Registry`)**: Every database table and column must be declared with an explicit boolean `encrypted: true|false`, optional `deterministic: true|false`, and a human-meaningful `comment` when unencrypted or ignored.
2. **Static Auditor (`MechaEncrypt::Auditor::Static`)**: Compares the live database schema (`ActiveRecord::Base.connection`), the YAML registry, and loaded `ApplicationRecord` descendants to catch unmapped tables/columns, model vs. YAML mismatches, stale YAML entries, and low-effort comments.
3. **Behavioral Prober (`MechaEncrypt::Auditor::Prober` & `MechaEncrypt::MatrixTest`)**: Verifies at runtime that encrypted attribute types serialize into valid `ActiveRecord::Encryption` JSON envelopes (`{"p":...}`), round-trip cleanly, obey deterministic vs. non-deterministic IV semantics, avoid broken B-tree indexes on non-deterministic columns, and persist actual ciphertext in raw SQL.

---

## 2. Configuration (`MechaEncrypt::Configuration`)

Defined in `lib/mecha_encrypt/configuration.rb`, `MechaEncrypt.configuration` manages:
- `config_path`: Path to the YAML registry (defaults to `Rails.root.join("config/mecha_encrypt.yml")` when Rails is present, or `"config/mecha_encrypt.yml"`).
- `base_model_class`: Root ActiveRecord class name used for model discovery (defaults to `"ApplicationRecord"`).
- `internal_tables`: Framework metadata tables automatically excluded from auditing (`["schema_migrations", "ar_internal_metadata"]`).
- `min_comment_length`: Minimum character length for required explanations on unencrypted columns and ignored table patterns (defaults to `10`).
- `forbidden_comments`: Denylist of placeholder strings (`todo`, `tbd`, `n/a`, `none`, `unencrypted`, `fixme`, `test`, `ok`, etc.).
- `debug_colorization`: Terminal color mapping (`tiny_color` symbols) for `bin/rails mecha_encrypt` output (`:encrypted`, `:deterministic`, `:unencrypted`, `:ignored`, `:violation`, `:unmapped`).
- `test_setup`, `test_teardown`, `test_records`: Procs registered via `configure_test_matrix` for behavioral persistence testing in `MechaEncrypt::MatrixTest`.

---

## 3. Pillar 1: Central Registry (`MechaEncrypt::Registry`)

Defined in `lib/mecha_encrypt/registry.rb`, `MechaEncrypt::Registry` loads and validates `config/mecha_encrypt.yml` (or an in-memory Hash):

### Schema Rules
- Top-level `tables` key is required (supports either a Hash keyed by table name or an Array of `{"table" => ..., "columns" => ...}` entries; duplicate table entries raise `MechaEncrypt::ConfigurationError`).
- Every column definition must be a Hash with an explicit boolean `encrypted: true` or `encrypted: false`.
- `deterministic` defaults to `false`. If specified, it must be a boolean (`true` or `false`).
- Setting `deterministic: true` when `encrypted: false` raises `MechaEncrypt::ConfigurationError`.
- `ignored_tables` accepts an Array of Hashes with `pattern` (or `table`) and `comment`. Patterns are matched against database table names via `File.fnmatch?` (e.g., `solid_queue_*`), and duplicate patterns raise `MechaEncrypt::ConfigurationError`.
- All parsed table, column, and ignored-table structures are deeply frozen after load.

---

## 4. Pillar 2: Static Auditor (`MechaEncrypt::Auditor::Static`)

Defined in `lib/mecha_encrypt/auditor/static.rb`, the static auditor inspects the database connection, model hierarchy, and registry to return a `MechaEncrypt::Auditor::Static::Result`:

### Verification Checks
1. **Unmapped Tables (`unmapped_tables`)**: Database tables (excluding `internal_tables` and `ignored_tables` matches) that are absent from `tables` in `config/mecha_encrypt.yml`.
2. **Unmapped Columns (`unmapped_columns`)**: Database columns present in the live schema but missing from the table's YAML definition.
3. **Model Encryption Parity (`unencrypted_in_model` & `undeclared_encrypted_in_model`)**:
   - Discovers concrete `ApplicationRecord` descendants (`discover_models_by_table`) after calling `Rails.application.eager_load!`.
   - Checks `model.encrypted_attributes` and `model.type_for_attribute(col).deterministic?`.
   - Flags columns marked `encrypted: true` in YAML that lack `encrypts :<col>` on the model, and columns with `encrypts :<col>` on the model marked `encrypted: false` in YAML.
4. **Determinism Mode Parity (`mode_mismatches`)**: Flags columns where YAML `deterministic` (`true`/`false`) disagrees with the model's `type_for_attribute(col).deterministic?`.
5. **Comment Quality Enforcement (`validate_comment` / `invalid_comments`)**:
   - Required for every `encrypted: false` column and every `ignored_tables` entry.
   - Rejects blank comments, comments shorter than `min_comment_length` (10 chars), normalized matches against `forbidden_comments`, comments with fewer than 2 alphabetic words (`/[a-zA-Z]{2,}/`), or strings with fewer than 4 unique non-whitespace characters (e.g. `"aaaaaaaaaaaa"`).
6. **Dead Entry Hygiene (`dead_tables`, `dead_columns`, `dead_ignored_patterns`)**:
   - Flags tables in YAML that do not exist in the DB or are simultaneously matched by `ignored_tables`.
   - Flags columns in YAML that no longer exist on the database table.
   - Flags `ignored_tables` glob patterns that matched zero database tables.

---

## 5. Pillar 3: Behavioral Prober (`MechaEncrypt::Auditor::Prober`) & `MatrixTest`

Defined in `lib/mecha_encrypt/auditor/prober.rb` and `lib/mecha_encrypt/matrix_test.rb`:

### 5.1 Index Safety Probing (`probe_index_safety`)
- Inspects `connection.indexes(table_name)` for every table in the registry.
- If a column is registered as `encrypted: true` and `deterministic: false`, verifies that no database index covers that column. Non-deterministic encryption uses random IVs per write, which silently breaks B-tree equality lookups and unique index constraints.

### 5.2 Attribute Type Serialization & IV Probing (`probe_encryption_types` / `probe_single_column_type`)
- Generates a unique probe plaintext (`"mecha_secret_#{table}_#{column}_#{SecureRandom.hex(8)}"`).
- Serializes the plaintext twice (`cipher1`, `cipher2`) through `model.type_for_attribute(col_name)`.
- Verifies:
  1. Output is a String starting with `{"p":` (ActiveRecord::Encryption JSON envelope) and does not leak the plaintext substring.
  2. `attr_type.deserialize(cipher1)` round-trips back to the exact `probe_plaintext`.
  3. If `deterministic: true`, `cipher1 == cipher2`.
  4. If `deterministic: false`, `cipher1 != cipher2` (proving random IV generation).

### 5.3 Raw SQL Persistence Probing (`probe_persisted_records` / `probe_single_table_persisted_record`)
- Given persisted test records provided by `MechaEncrypt.configuration.test_records`:
  1. Reads the plaintext attribute via `record.public_send(col_name)` and ensures it is non-empty.
  2. Executes a raw SQL query (`SELECT "col" FROM "table" WHERE id = ...`) via `connection.select_value` bypassing ActiveRecord type casting.
  3. Asserts the raw database value starts with `{"p":` and does not contain the plaintext value (`PLAINTEXT LEAK IN DB` detection).
  4. Reloads the record (`record.class.find(record.id)`) and verifies decryption back to the original plaintext.

### 5.4 Dynamic Parallel Test Generation (`MechaEncrypt::MatrixTest`)
- Subclasses `ActionDispatch::IntegrationTest` and calls `define_encrypt_matrix_tests!` at load time.
- Dynamically defines:
  - Static audit zero-violation test.
  - Database index safety test + synthetic fault-injection test verifying the prober catches a non-deterministic encrypted column on an indexed column.
  - One test method per encrypted column (`probe_single_column_type`).
  - One test method per table with encrypted columns (`probe_single_table_persisted_record`).

---

## 6. Railtie & Rake Tasks (`lib/tasks/mecha_encrypt.rake`)

Loaded automatically via `MechaEncrypt::Railtie` when `Rails::Railtie` is present:
- `bin/rails mecha_encrypt`: Prints all tables and columns alphabetically with color-coded status (`ENCRYPTED`, `ENCRYPTED (DETERMINISTIC)`, `NOT ENCRYPTED`, `IGNORED TABLE`, `UNMAPPED`, `VIOLATION`) and comments/violation messages.
- `bin/rails mecha_encrypt:verify:static`: Runs `MechaEncrypt::Auditor::Static` and exits non-zero (`abort`) on any violation.
- `bin/rails mecha_encrypt:verify:behavioral`: Executes `lib/mecha_encrypt/matrix_test.rb` via `bin/rails test` with `MECHA_MATRIX_STANDALONE=1`.
- `bin/rails mecha_encrypt:verify`: Runs both `verify:static` and `verify:behavioral`.
