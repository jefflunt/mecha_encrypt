# MechaEncrypt — Project Knowledge & Overview

## Mission

`mecha_encrypt` enforces closed-by-default database column encryption parity for Ruby on Rails applications using `ActiveRecord::Encryption`. Instead of relying on developers to remember `encrypts :column_name` on every sensitive model attribute or risking broken B-tree indexes on non-deterministic columns, `mecha_encrypt` requires every table and column in the database schema to be explicitly declared in `config/mecha_encrypt.yml` with its encryption status, determinism mode, and justification.

It implements the three-pillar **MechaRuby** security pattern:
1. **Central Registry (`config/mecha_encrypt.yml` + `MechaEncrypt::Registry`)** — Single source of truth mapping database tables and columns to explicit `encrypted: true|false` and `deterministic: true|false` flags, plus glob-based `ignored_tables` patterns and required human-meaningful `comment` explanations for unencrypted columns and ignored tables.
2. **Static Auditor (`MechaEncrypt::Auditor::Static`)** — Compares the live database schema (`ActiveRecord::Base.connection`), the YAML registry, and `ApplicationRecord` descendants (`encrypted_attributes`) to detect unmapped tables/columns, model vs. YAML mismatches, determinism mismatches, dead/stale YAML entries, and placeholder comments.
3. **Behavioral Prober (`MechaEncrypt::Auditor::Prober` + `MechaEncrypt::MatrixTest`)** — Verifies at runtime that non-deterministic encrypted columns are not covered by database indexes (`probe_index_safety`), probes attribute type serialization/deserialization round-trips and IV randomness (`probe_encryption_types`), and executes raw SQL `SELECT` queries against persisted records (`probe_persisted_records`) to guarantee actual ciphertext storage in the database.

## Directory Layout

- `lib/mecha_encrypt.rb` — Top-level module, configuration singleton, and registry lifecycle (`configure`, `registry`, `reload!`, `reset_configuration!`).
- `lib/mecha_encrypt/version.rb` — Gem version constant (`MechaEncrypt::VERSION`).
- `lib/mecha_encrypt/errors.rb` — Custom error hierarchy (`MechaEncrypt::Error`, `MechaEncrypt::ConfigurationError`).
- `lib/mecha_encrypt/configuration.rb` — Configuration object (`config_path`, `base_model_class`, `internal_tables`, `min_comment_length`, `forbidden_comments`, `debug_colorization`, `configure_test_matrix`).
- `lib/mecha_encrypt/registry.rb` — YAML parser and schema validator for `config/mecha_encrypt.yml`.
- `lib/mecha_encrypt/auditor/static.rb` — Static database schema, model `encrypts` declaration, and comment quality auditor.
- `lib/mecha_encrypt/auditor/prober.rb` — Behavioral index safety, attribute type ciphertext/IV, and raw SQL persistence prober.
- `lib/mecha_encrypt/matrix_test.rb` — `ActionDispatch::IntegrationTest` subclass that dynamically generates per-column and per-table test methods for parallel Minitest execution.
- `lib/mecha_encrypt/railtie.rb` & `lib/tasks/mecha_encrypt.rake` — Automatic Railtie registration for `rails mecha_encrypt`, `rails mecha_encrypt:verify:static`, `rails mecha_encrypt:verify:behavioral`, and `rails mecha_encrypt:verify`.
- `test/` — Standalone Minitest unit test suite (`bundle exec rake test`).
