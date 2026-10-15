# Knowledge Log

Chronological history of discoveries, architectural milestones, and implementation updates for `mecha_encrypt`.

### 2026-10-15

- **Initial Release (`v0.1.0`)**:
  - **Central Encryption Registry (`MechaEncrypt::Registry`)**: Implemented YAML configuration loader and validator for `config/mecha_encrypt.yml` supporting table/column encryption declarations (`encrypted`, `deterministic`, `comment`), glob-based `ignored_tables`, and custom `debug_colorization`.
  - **Static Schema & Model Auditor (`MechaEncrypt::Auditor::Static`)**: Built static verification comparing live ActiveRecord database tables/columns against `config/mecha_encrypt.yml` and `ApplicationRecord` `encrypts` declarations, including anti-placeholder comment validation and dead table/column/pattern detection.
  - **Behavioral Ciphertext & Index Safety Prober (`MechaEncrypt::Auditor::Prober`)**: Implemented B-tree index safety verification for non-deterministic encrypted columns, attribute type serialization/deserialization & IV randomness probing, and raw SQL `SELECT` persistence probing to detect plaintext leaks.
  - **Dynamic Matrix Test Suite (`MechaEncrypt::MatrixTest`) & Rake Tasks (`MechaEncrypt::Railtie`)**: Added dynamic per-column and per-table Minitest generation alongside `mecha_encrypt`, `mecha_encrypt:verify:static`, `mecha_encrypt:verify:behavioral`, and `mecha_encrypt:verify` Rake tasks.
  - **Repository Hygiene & OKF Backfill**: Added `.gitignore` (excluding `*.gem`, `/pkg/`, bundler caches, coverage, temp/log files, and OS/editor files) and initialized the `.okf/` v0.2 knowledge base.
