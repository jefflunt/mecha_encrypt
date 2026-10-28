# AI Agent Contributing Guidelines — mecha_encrypt

Welcome. This repository is part of the **MechaRuby** suite of opinionated, closed-by-default security and architecture tools for Ruby on Rails.

When analyzing this codebase, submitting PRs, or filing issues, adhere to the following principles:

## 1. Core Architectural Tenets
* **Closed-by-Default Encryption**: Every table and column across the database schema must be explicitly declared (`encrypted`, `deterministic`, `unencrypted` with justification, or `ignored`).
* **Meaningful Justification**: Unencrypted columns require a thoughtful, substantive `comment:`. Placeholder explanations ("todo", "n/a", "temp") MUST fail validation.
* **Deterministic Search Safety**: Deterministic encryption allows queries but leaks equality patterns; non-deterministic encryption provides maximum security. Audits must ensure columns intended for querying are intentionally classified.
* **Schema Parity & Live Probing**: Statically auditable against `db/schema.rb`, and actively verifiable against live database ciphertext and indices.

## 2. Guidelines for Filing Issues & Suggestions
* **Check Existing Issues**: Search existing open and closed issues before opening a duplicate.
* **Provide Realistic Schema & Model Snippets**: Supply minimal ActiveRecord model definitions (`encrypts :attr`) and database migration snippets.
* **Preserve Justification Enforcement**: Any proposals to change configuration syntax must retain the requirement that unencrypted columns cannot silently slip into the database.

## 3. Pull Request Standards
* Include automated tests verifying schema parity checks, invalid comment rejections, and ciphertext probers.
* Run the test suite (`bundle exec rake test`) and ensure zero regressions.
* Keep dependencies minimal—target native `ActiveRecord::Encryption` and standard Rails components.
