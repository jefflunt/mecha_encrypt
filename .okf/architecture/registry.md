---
type: Component
title: Central Encryption Registry
description: YAML schema loader, validator, and configuration singleton for `config/mecha_encrypt.yml`.
tags: [registry, configuration, yaml, schema]
status: stable
generated: { by: antigravity/gemini-4-argon, at: 2026-10-15T23:25:00Z }
verified: { by: process:rake-test, at: 2026-10-15T23:25:00Z }
sources:
  - id: registry-rb
    resource: ../../lib/mecha_encrypt/registry.rb
    title: MechaEncrypt::Registry Source
    author: human:jefflunt
    last_modified: 2026-10-15T20:54:00Z
  - id: config-rb
    resource: ../../lib/mecha_encrypt/configuration.rb
    title: MechaEncrypt::Configuration Source
    author: human:jefflunt
    last_modified: 2026-10-15T20:54:00Z
  - id: errors-rb
    resource: ../../lib/mecha_encrypt/errors.rb
    title: MechaEncrypt::Errors Source
    author: human:jefflunt
    last_modified: 2026-10-15T20:54:00Z
---

# Configuration (`MechaEncrypt::Configuration`)

`MechaEncrypt.configuration` holds runtime settings for the [MechaEncrypt Overview](/overview.md) pipeline:[^config-rb]

| Attribute | Default | Description |
|-----------|---------|-------------|
| `config_path` | `Rails.root.join("config/mecha_encrypt.yml")` or `"config/mecha_encrypt.yml"` | Path to the YAML encryption registry file. |
| `base_model_class` | `"ApplicationRecord"` | Base class whose concrete descendants are discovered by the [Static Schema & Model Auditor](/architecture/static-auditor.md) and [Behavioral Ciphertext & Index Prober](/architecture/behavioral-prober.md). |
| `internal_tables` | `["schema_migrations", "ar_internal_metadata"]` | Framework tables automatically excluded from schema auditing. |
| `min_comment_length` | `10` | Minimum length for required comments on unencrypted columns and ignored table patterns. |
| `forbidden_comments` | `["todo", "tbd", "n/a", "na", "none", "nil", "null", "unencrypted", "not_encrypted", "not encrypted", "fixme", "reason", "comment", "test", "ok", "yes", "no", "later", "skip"]` | Placeholder strings rejected by comment validation. |
| `debug_colorization` | `{ encrypted: :green, deterministic: :light_cyan, unencrypted: :light_purple, ignored: :yellow, violation: :light_red, unmapped: :dark_grey }` | Terminal output colors merged with optional `debug_colorization` overrides from YAML. |
| `test_setup`, `test_teardown`, `test_records` | `nil` | Hooks configured via `configure_test_matrix` for [Dynamic Matrix Test & Railtie Rake Tasks](/architecture/matrix-test-and-railtie.md). |

# Schema Registry (`MechaEncrypt::Registry`)

`MechaEncrypt::Registry` loads and validates `config/mecha_encrypt.yml` (or an in-memory Hash), raising `MechaEncrypt::ConfigurationError` on any structural or semantic error.[^registry-rb][^errors-rb]

## Validation Rules

1. **Top-level `tables` Required**: Must be a `Hash` mapping table names to column hashes, or an `Array` of `{"table" => ..., "columns" => ...}` entries (duplicate table names raise `ConfigurationError`).[^registry-rb]
2. **Explicit Boolean `encrypted`**: Every column definition must be a `Hash` with `encrypted: true` or `encrypted: false`. Non-boolean values (e.g., `"yes"` or `nil`) raise `ConfigurationError`.[^registry-rb]
3. **Boolean `deterministic`**: Defaults to `false`. When specified, must be `true` or `false`. Specifying `deterministic: true` when `encrypted: false` raises `ConfigurationError`.[^registry-rb]
4. **Glob-based `ignored_tables`**: Optional `Array` of `Hash` entries containing `pattern` (or `table`) and `comment`. Matched against database table names via `File.fnmatch?` (`ignored_table_entry_for`). Duplicate patterns raise `ConfigurationError`.[^registry-rb]
5. **Immutability**: Parsed `@tables`, column entries, and `@ignored_tables` entries are frozen immediately after parsing.[^registry-rb]

# Examples

```yaml
debug_colorization:
  encrypted: :green
  unencrypted: :light_purple

ignored_tables:
  - pattern: "solid_queue_*"
    comment: "SolidQueue internal background job coordination tables"

tables:
  users:
    id:
      encrypted: false
      comment: "Primary key UUID identifier for joins"
    email:
      encrypted: true
      deterministic: true
      comment: "User email address encrypted deterministically for lookups"
    secret_token:
      encrypted: true
      deterministic: false
      comment: "Encrypted API secret token"
```

[^registry-rb]: MechaEncrypt::Registry Source
[^config-rb]: MechaEncrypt::Configuration Source
[^errors-rb]: MechaEncrypt::Errors Source
