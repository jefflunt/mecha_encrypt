---
type: Component
title: Static Schema & Model Auditor
description: Database schema parity, `ActiveRecord::Encryption` model declaration introspection, and comment quality enforcement.
tags: [auditor, static-analysis, schema, activerecord]
status: stable
generated: { by: antigravity/gemini-4-argon, at: 2026-10-15T23:25:00Z }
verified: { by: process:rake-test, at: 2026-10-15T23:25:00Z }
sources:
  - id: static-rb
    resource: ../../lib/mecha_encrypt/auditor/static.rb
    title: MechaEncrypt::Auditor::Static Source
    author: human:jefflunt
    last_modified: 2026-10-15T20:54:00Z
---

# Overview

`MechaEncrypt::Auditor::Static` cross-checks three sources of truth without mutating database state:[^static-rb]
1. The live database schema (`connection.tables` and `connection.columns(table_name)`).
2. The [Central Encryption Registry](/architecture/registry.md) (`MechaEncrypt.registry`).
3. Loaded `ApplicationRecord` descendants (`model.encrypted_attributes` and `model.type_for_attribute(col).deterministic?`).

It returns a `MechaEncrypt::Auditor::Static::Result` struct where `#success?` is `true` only when all nine violation collections are empty.[^static-rb]

# Audit Checks

| Result Field | Violation Condition |
|--------------|---------------------|
| `unmapped_tables` | Database table (not in `internal_tables` and not matched by `ignored_tables`) is missing from `tables` in `config/mecha_encrypt.yml`. |
| `unmapped_columns` | Database column exists on an audited table but is missing from the table's YAML column definitions. |
| `unencrypted_in_model` | Column is registered with `encrypted: true` in YAML, but the table's ActiveRecord model does not declare `encrypts :<column>` (or no model exists for the table). |
| `undeclared_encrypted_in_model` | Column declares `encrypts :<column>` on the ActiveRecord model, but is registered with `encrypted: false` in YAML. |
| `mode_mismatches` | Column is encrypted in both YAML and the model, but YAML `deterministic` disagrees with `model.type_for_attribute(col).deterministic?`. |
| `invalid_comments` | An `encrypted: false` column or `ignored_tables` entry fails `#validate_comment`. |
| `dead_tables` | Table listed in YAML `tables` does not exist in the database, or is simultaneously matched by an `ignored_tables` pattern. |
| `dead_columns` | Column listed in YAML `tables[table]` does not exist in the database table. |
| `dead_ignored_patterns` | Glob pattern in `ignored_tables` matched zero database tables. |

# Comment Validation (`#validate_comment`)

Every `encrypted: false` column and every `ignored_tables` rule must carry a meaningful justification.[^static-rb] `#validate_comment` rejects a comment if:
1. It is blank (`empty?`).
2. Its length is less than `configuration.min_comment_length` (default `10`).
3. Its normalized text matches any entry in `configuration.forbidden_comments` (`todo`, `tbd`, `n/a`, `none`, `unencrypted`, etc.).
4. It contains fewer than 2 multi-letter alphabetic words (`text.scan(/[a-zA-Z]{2,}/).size < 2`) or fewer than 4 unique non-whitespace characters (`text.gsub(/\s+/, "").chars.uniq.size < 4`).[^static-rb]

[^static-rb]: MechaEncrypt::Auditor::Static Source
