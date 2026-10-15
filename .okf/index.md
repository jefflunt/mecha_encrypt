---
okf_version: "0.2"
---

# Overview

* [MechaEncrypt Overview](overview.md) - Closed-by-default database column encryption registry and three-pillar auditing toolkit for Ruby on Rails applications.

# Architecture

* [Architecture Subdirectory](architecture/) - Component specifications for the YAML schema registry, static schema/model auditor, behavioral ciphertext/index prober, and dynamic Minitest matrix suite.
* [Central Encryption Registry](architecture/registry.md) - YAML schema loader, validator, and configuration singleton for `config/mecha_encrypt.yml`.
* [Static Schema & Model Auditor](architecture/static-auditor.md) - Database schema parity, `ActiveRecord::Encryption` model declaration introspection, and comment quality enforcement.
* [Behavioral Ciphertext & Index Prober](architecture/behavioral-prober.md) - Runtime B-tree index safety checks, attribute type serialization/IV probing, and raw SQL ciphertext verification.
* [Dynamic Matrix Test & Railtie Rake Tasks](architecture/matrix-test-and-railtie.md) - Parallel per-column and per-table Minitest generation and Rails Rake tasks for static and behavioral verification.
