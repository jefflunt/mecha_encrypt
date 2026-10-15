---
type: Component
title: Dynamic Matrix Test & Railtie Rake Tasks
description: Parallel per-column and per-table Minitest generation and Rails Rake tasks for static and behavioral verification.
tags: [minitest, matrix-test, railtie, rake, cli]
status: stable
generated: { by: antigravity/gemini-4-argon, at: 2026-10-15T23:25:00Z }
verified: { by: process:rake-test, at: 2026-10-15T23:25:00Z }
sources:
  - id: matrix-rb
    resource: ../../lib/mecha_encrypt/matrix_test.rb
    title: MechaEncrypt::MatrixTest Source
    author: human:jefflunt
    last_modified: 2026-10-15T20:54:00Z
  - id: rake-rb
    resource: ../../lib/tasks/mecha_encrypt.rake
    title: MechaEncrypt Rake Tasks Source
    author: human:jefflunt
    last_modified: 2026-10-15T20:54:00Z
  - id: railtie-rb
    resource: ../../lib/mecha_encrypt/railtie.rb
    title: MechaEncrypt::Railtie Source
    author: human:jefflunt
    last_modified: 2026-10-15T20:54:00Z
---

# Dynamic Matrix Test (`MechaEncrypt::MatrixTest`)

`MechaEncrypt::MatrixTest` subclasses `ActionDispatch::IntegrationTest` to integrate directly with a consuming Rails application's parallel Minitest suite.[^matrix-rb]

## Generated Test Methods

1. **`static database and model encryption audit passes with zero violations`**: Runs the [Static Schema & Model Auditor](/architecture/static-auditor.md) and asserts all violation lists are empty.[^matrix-rb]
2. **`behavioral prober verifies database index safety for all encrypted columns`**: Runs `Prober#probe_index_safety` via the [Behavioral Ciphertext & Index Prober](/architecture/behavioral-prober.md).[^matrix-rb]
3. **`behavioral prober catches non-deterministic encrypted column covered by a database index`**: Fault-injection test that clones the registry, marks an indexed column as `encrypted: true, deterministic: false`, and asserts `Prober#probe_index_safety` flags it.[^matrix-rb]
4. **Per-Column Serialization & IV Tests**: `define_encrypt_matrix_tests!` iterates over `MechaEncrypt.registry.encrypted_columns` and defines `"behavioral ciphertext serialization and determinism for #{table}.#{col}"` calling `Prober#probe_single_column_type`.[^matrix-rb]
5. **Per-Table Raw SQL Persistence Tests**: Groups encrypted columns by table and defines `"behavioral raw SQL ciphertext persistence for table #{table}"` calling `Prober#probe_single_table_persisted_record`.[^matrix-rb]

# Railtie & Rake Tasks

`MechaEncrypt::Railtie` automatically loads `lib/tasks/mecha_encrypt.rake` in Rails applications:[^railtie-rb][^rake-rb]

| Task | Behavior |
|------|----------|
| `bin/rails mecha_encrypt` | Prints all database tables and columns in alphabetical order with colorized status (`ENCRYPTED`, `ENCRYPTED (DETERMINISTIC)`, `NOT ENCRYPTED`, `IGNORED TABLE`, `UNMAPPED`, `VIOLATION`) and comments/violations. |
| `bin/rails mecha_encrypt:verify:static` | Runs `MechaEncrypt::Auditor::Static#audit`, prints detailed violation lists, and calls `abort` on failure. |
| `bin/rails mecha_encrypt:verify:behavioral` | Runs `bin/rails test` against `lib/mecha_encrypt/matrix_test.rb` with `MECHA_MATRIX_STANDALONE=1`. |
| `bin/rails mecha_encrypt:verify` | Composite task running both `verify:static` and `verify:behavioral`. |

[^matrix-rb]: MechaEncrypt::MatrixTest Source
[^rake-rb]: MechaEncrypt Rake Tasks Source
[^railtie-rb]: MechaEncrypt::Railtie Source
