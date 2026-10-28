---
name: Bug Report
about: Report a schema audit discrepancy, false positive, false negative, or ciphertext probe issue
title: "[Bug]: "
labels: ["bug"]
assignees: ""
---

### Describe the Bug
A clear and concise description of the unexpected behavior.

### Type of Issue
- [ ] Schema vs. registry parity mismatch
- [ ] False positive on ActiveRecord::Encryption model declarations
- [ ] False negative (unregistered or unencrypted column slipped past audit)
- [ ] Live ciphertext / database prober error
- [ ] Unencrypted column comment validation error
- [ ] CLI / reporting formatting issue

### Minimal Reproduction
1. Rails version:
2. Ruby version:
3. Minimal Model & Migration snippet:

```ruby
# app/models/... or db/migrate/...
```

4. Minimal configuration (`config/mecha_encrypt.yml`):

```yaml
# Relevant config snippet
```

### Expected Behavior
What should the audit or live prober have reported instead?
