---
type: Reference
title: MechaEncrypt Overview
description: Closed-by-default database column encryption registry and three-pillar auditing toolkit for Ruby on Rails applications.
resource: https://github.com/jefflunt/mecha_encrypt
tags: [ruby, rails, activerecord, encryption, security, auditing]
status: stable
generated: { by: antigravity/gemini-4-argon, at: 2026-10-15T23:25:00Z }
verified: { by: process:rake-test, at: 2026-10-15T23:25:00Z }
sources:
  - id: gemspec
    resource: ../mecha_encrypt.gemspec
    title: MechaEncrypt Gem Specification
    author: human:jefflunt
    last_modified: 2026-10-15T23:07:00Z
  - id: entrypoint
    resource: ../lib/mecha_encrypt.rb
    title: MechaEncrypt Module Entrypoint
    author: human:jefflunt
    last_modified: 2026-10-15T20:54:00Z
  - id: readme
    resource: ../README.md
    title: MechaEncrypt README
    author: human:jefflunt
    last_modified: 2026-10-15T21:24:00Z
---

# Summary

`mecha_encrypt` enforces closed-by-default database column encryption parity in Ruby on Rails applications (`>= 7.0`, Ruby `>= 3.2.0`) using `ActiveRecord::Encryption`.[^gemspec] Every database table and column must be explicitly registered in `config/mecha_encrypt.yml` with its encryption posture (`encrypted: true|false`), determinism mode (`deterministic: true|false`), and human-meaningful justification (`comment`).[^readme]

# Three-Pillar Architecture

`mecha_encrypt` implements the three-pillar **MechaRuby** verification model:

1. **[Central Encryption Registry](/architecture/registry.md)**: Loads and validates `config/mecha_encrypt.yml` via `MechaEncrypt::Registry` and exposes global configuration through `MechaEncrypt.configuration`.[^entrypoint]
2. **[Static Schema & Model Auditor](/architecture/static-auditor.md)**: Compares live database tables and columns against `config/mecha_encrypt.yml` and `ApplicationRecord` descendants (`encrypted_attributes`) via `MechaEncrypt::Auditor::Static`.
3. **[Behavioral Ciphertext & Index Prober](/architecture/behavioral-prober.md)**: Verifies B-tree index safety for non-deterministic columns, attribute type ciphertext envelope/IV behavior, and raw SQL persistence via `MechaEncrypt::Auditor::Prober` and [Dynamic Matrix Test & Railtie Rake Tasks](/architecture/matrix-test-and-railtie.md).

# Repository Layout

| Path | Role |
|------|------|
| `lib/mecha_encrypt.rb` | Top-level `MechaEncrypt` singleton (`configuration`, `configure`, `registry`, `reload!`, `reset_configuration!`).[^entrypoint] |
| `lib/mecha_encrypt/version.rb` | Defines `MechaEncrypt::VERSION` (`"0.1.0"`). |
| `lib/mecha_encrypt/errors.rb` | Defines `MechaEncrypt::Error` and `MechaEncrypt::ConfigurationError`. |
| `lib/mecha_encrypt/configuration.rb` | Defines [Central Encryption Registry](/architecture/registry.md) runtime settings (`MechaEncrypt::Configuration`). |
| `lib/mecha_encrypt/registry.rb` | Parses and validates `config/mecha_encrypt.yml` (`MechaEncrypt::Registry`). |
| `lib/mecha_encrypt/auditor/static.rb` | Static schema, model, and comment auditor (`MechaEncrypt::Auditor::Static`). |
| `lib/mecha_encrypt/auditor/prober.rb` | Behavioral index safety, type serialization, and raw SQL prober (`MechaEncrypt::Auditor::Prober`). |
| `lib/mecha_encrypt/matrix_test.rb` | Dynamic parallel `ActionDispatch::IntegrationTest` suite (`MechaEncrypt::MatrixTest`). |
| `lib/mecha_encrypt/railtie.rb` | Rails `Railtie` loading `lib/tasks/mecha_encrypt.rake`. |
| `lib/tasks/mecha_encrypt.rake` | Defines `mecha_encrypt`, `mecha_encrypt:verify:static`, `mecha_encrypt:verify:behavioral`, and `mecha_encrypt:verify`. |
| `test/mecha_encrypt_test.rb` | Standalone Minitest unit test suite (`bundle exec rake test`). |

# Examples

```ruby
# config/initializers/mecha_encrypt.rb
require "mecha_encrypt"

MechaEncrypt.configure do |config|
  config.config_path = Rails.root.join("config/mecha_encrypt.yml")
  config.base_model_class = "ApplicationRecord"
  config.min_comment_length = 10
end
```

[^gemspec]: MechaEncrypt Gem Specification
[^entrypoint]: MechaEncrypt Module Entrypoint
[^readme]: MechaEncrypt README
