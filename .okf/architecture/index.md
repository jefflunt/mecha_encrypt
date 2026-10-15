# Architecture Components

* [Central Encryption Registry](registry.md) - YAML schema loader, validator, and configuration singleton for `config/mecha_encrypt.yml`.
* [Static Schema & Model Auditor](static-auditor.md) - Database schema parity, `ActiveRecord::Encryption` model declaration introspection, and comment quality enforcement.
* [Behavioral Ciphertext & Index Prober](behavioral-prober.md) - Runtime B-tree index safety checks, attribute type serialization/IV probing, and raw SQL ciphertext verification.
* [Dynamic Matrix Test & Railtie Rake Tasks](matrix-test-and-railtie.md) - Parallel per-column and per-table Minitest generation and Rails Rake tasks for static and behavioral verification.
