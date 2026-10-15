---
type: Component
title: Behavioral Ciphertext & Index Prober
description: Runtime B-tree index safety checks, attribute type serialization/IV probing, and raw SQL ciphertext verification.
tags: [prober, behavioral-testing, ciphertext, database-indexes, sql]
status: stable
generated: { by: antigravity/gemini-4-argon, at: 2026-10-15T23:25:00Z }
verified: { by: process:rake-test, at: 2026-10-15T23:25:00Z }
sources:
  - id: prober-rb
    resource: ../../lib/mecha_encrypt/auditor/prober.rb
    title: MechaEncrypt::Auditor::Prober Source
    author: human:jefflunt
    last_modified: 2026-10-15T20:54:00Z
---

# Overview

While the [Static Schema & Model Auditor](/architecture/static-auditor.md) verifies declarations, `MechaEncrypt::Auditor::Prober` verifies runtime behavior across three failure modes that static reflection alone cannot catch.[^prober-rb] It is invoked by [Dynamic Matrix Test & Railtie Rake Tasks](/architecture/matrix-test-and-railtie.md).

# Behavioral Probes

## 1. Database Index Safety (`#probe_index_safety`)

Non-deterministic encryption generates a random initialization vector (IV) on every encryption call, producing different ciphertexts for identical plaintexts. Placing a B-tree or unique index on a non-deterministic encrypted column breaks equality queries and uniqueness enforcement.[^prober-rb]

`#probe_index_safety` inspects `connection.indexes(table_name)` for every registered table and records an `IndexFailure` if any column with `encrypted: true` and `deterministic: false` is covered by a database index.[^prober-rb]

## 2. Attribute Type Serialization & IV Semantics (`#probe_encryption_types` / `#probe_single_column_type`)

For each encrypted column in the [Central Encryption Registry](/architecture/registry.md), `#probe_single_column_type`:[^prober-rb]
1. Generates a unique probe string: `"mecha_secret_#{table_name}_#{col_name}_#{SecureRandom.hex(8)}"`.
2. Serializes the probe string twice (`cipher1`, `cipher2`) via `model_klass.type_for_attribute(col_name).serialize(...)`.
3. Verifies that `cipher1` is a `String` starting with `{"p":` (`ActiveRecord::Encryption` envelope format) and does not contain the plaintext substring.
4. Verifies round-trip decryption: `attr_type.deserialize(cipher1) == probe_plaintext`.
5. Verifies IV determinism:
   - If `deterministic: true`, requires `cipher1 == cipher2`.
   - If `deterministic: false`, requires `cipher1 != cipher2`.

## 3. Raw SQL Persistence Verification (`#probe_persisted_records` / `#probe_single_table_persisted_record`)

Using persisted sample records supplied via `MechaEncrypt.configuration.test_records`, `#probe_single_table_persisted_record`:[^prober-rb]
1. Reads the non-empty plaintext attribute from the model instance (`record.public_send(col_name).to_s`).
2. Executes a raw SQL query bypassing ActiveRecord type casting:
   ```sql
   SELECT "col_name" FROM "table_name" WHERE id = '<record.id>'
   ```
3. Records a `PLAINTEXT LEAK IN DB` `CipherFailure` if the raw SQL value is empty, contains the plaintext string, or does not start with `{"p":`.
4. Reloads the record from the database (`record.class.find(record.id)`) and verifies that the decrypted attribute matches the original plaintext.

[^prober-rb]: MechaEncrypt::Auditor::Prober Source
