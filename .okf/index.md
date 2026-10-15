---
type: Knowledge Index
title: MechaEncrypt — Database Column Encryption Registry & Auditing Knowledge Base
schema_version: "0.2"
sources:
  - ref: "lib/mecha_encrypt.rb"
    type: source_code
  - ref: "mecha_encrypt.gemspec"
    type: source_code
verified: machine-confirmed
last_modified: "2026-10-15"
---

# MechaEncrypt Knowledge Catalog (`.okf`)

Welcome to the **MechaEncrypt** Open Knowledge Catalog. `mecha_encrypt` is a closed-by-default database column encryption registry and auditing library for Ruby on Rails applications using `ActiveRecord::Encryption`. Every database table and column must be explicitly registered in `config/mecha_encrypt.yml` with its encryption posture, determinism mode, and justification.

## Knowledge Structure

* **[Overview & Quick Reference](README.md)**: Gem mission, three-pillar security overview, and repository directory layout.
* **[Architecture & Auditing Pipeline](architecture/index.md)**: Full specification of the three-pillar MechaRuby architecture applied to database column encryption:
  1. **Central Registry (`MechaEncrypt::Registry`)** — YAML parser, schema validator, glob-based `ignored_tables` matcher, and column metadata store.
  2. **Static Auditor (`MechaEncrypt::Auditor::Static`)** — Database schema vs. YAML registry parity verification, `ActiveRecord::Encryption` (`encrypts`) model introspection, determinism mode checking, dead table/column detection, and anti-placeholder comment validation.
  3. **Behavioral Prober (`MechaEncrypt::Auditor::Prober`) & Matrix Test (`MechaEncrypt::MatrixTest`)** — B-tree / unique index safety checks for non-deterministic encrypted columns, live type serialization/deserialization round-trip & IV randomness probing, raw SQL ciphertext persistence verification, and parallel Minitest matrix generation.

## Change History

See [log.md](log.md) for the chronological record of gem development, architectural decisions, and releases.
