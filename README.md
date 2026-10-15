# MechaEncrypt

`mecha_encrypt` provides a closed-by-default database column encryption registry and auditing toolkit for Rails applications using `ActiveRecord::Encryption`. Every database table and column must be explicitly registered in `config/mecha_encrypt.yml` with its encryption status and justification.

## Installation

Add this line to your application's `Gemfile`:

```ruby
gem "mecha_encrypt"
```

Or if developing locally:

```ruby
gem "mecha_encrypt", path: "~/code/mecha_encrypt"
```

And then execute:

```bash
bundle install
```

## Usage

### 1. Define `config/mecha_encrypt.yml`

Register all database tables and columns in `config/mecha_encrypt.yml`. Unencrypted columns require a meaningful explanation in `comment:` (minimum length enforced, placeholder strings rejected).

```yaml
debug_colorization:
  encrypted: :green
  deterministic: :light_cyan
  unencrypted: :light_purple
  ignored: :yellow
  violation: :light_red
  unmapped: :dark_grey

ignored_tables:
  - pattern: "solid_queue_*"
    comment: "SolidQueue internal background job coordination tables"

tables:
  email_accounts:
    id:
      encrypted: false
      comment: "Primary key UUID identifier required for foreign key joins"
    email_address:
      encrypted: true
      deterministic: true
      comment: "User email address encrypted deterministically for lookups"
    oauth_token:
      encrypted: true
      deterministic: false
      comment: "OAuth access token encrypted with non-deterministic IV"
```

### 2. Configure the Initializer

Create `config/initializers/mecha_encrypt.rb`:

```ruby
# config/initializers/mecha_encrypt.rb
require "mecha_encrypt"

MechaEncrypt.configure do |config|
  config.config_path = Rails.root.join("config/mecha_encrypt.yml")
  config.base_model_class = "ApplicationRecord"
  config.min_comment_length = 10
end
```

### 3. Rake Tasks & Auditing

`mecha_encrypt` automatically registers Rake tasks via its Railtie:

```bash
# Print all database tables and columns in alphabetical order with encryption status
bin/rails mecha_encrypt

# Statically verify schema parity, ActiveRecord::Encryption declarations, and comments
bin/rails mecha_encrypt:verify:static

# Run behavioral ciphertext round-trip and index safety tests
bin/rails mecha_encrypt:verify:behavioral

# Run both static and behavioral verification
bin/rails mecha_encrypt:verify
```

### 4. Dynamic Parallel Matrix Testing in Consuming Apps

`mecha_encrypt` ships with [`MechaEncrypt::MatrixTest`](lib/mecha_encrypt/matrix_test.rb), which dynamically generates individual Minitest test methods for each encrypted column (type serialization, envelope format, and determinism) and each table with encrypted columns (raw SQL ciphertext verification), running in parallel across Minitest workers.

In your consuming Rails application's `test/test_helper.rb`:

```ruby
MechaEncrypt.configuration.configure_test_matrix(
  setup: -> {
    # Create persisted sample records for tables containing encrypted columns
    @records_by_table = {
      "email_accounts" => @account,
      "email_messages" => @message
    }
  },
  records: -> { @records_by_table }
)

require "mecha_encrypt/matrix_test" unless ENV["MECHA_MATRIX_STANDALONE"] == "1"
```

## Running Tests

To run the gem's standalone test suite:

```bash
bundle exec rake test
```

## License

Copyright 2026 Jeff Lunt. Released under the [MIT License](LICENSE).
