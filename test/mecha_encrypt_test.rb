# frozen_string_literal: true

require "test_helper"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/string/inflections"

class MechaEncryptTest < Minitest::Test
  FakeColumn = Struct.new(:name, :sql_type)
  FakeIndex = Struct.new(:name, :columns)

  class FakeConnection
    attr_accessor :tables_data, :indexes_data

    def initialize(tables_data = {}, indexes_data = {})
      @tables_data = tables_data
      @indexes_data = indexes_data
    end

    def tables
      @tables_data.keys
    end

    def table_exists?(name)
      @tables_data.key?(name.to_s)
    end

    def columns(table_name)
      @tables_data[table_name.to_s] || []
    end

    def indexes(table_name)
      @indexes_data[table_name.to_s] || []
    end
  end

  def setup
    MechaEncrypt.reset_configuration!
    @sample_config = {
      "debug_colorization" => {
        "encrypted" => ":green",
        "unencrypted" => ":light_purple"
      },
      "ignored_tables" => [
        {
          "pattern" => "solid_queue_*",
          "comment" => "SolidQueue background job coordination tables"
        }
      ],
      "tables" => {
        "users" => {
          "id" => {
            "encrypted" => false,
            "comment" => "Primary key UUID identifier for joins"
          },
          "email" => {
            "encrypted" => false,
            "comment" => "User email address used for authentication"
          },
          "secret_token" => {
            "encrypted" => true,
            "deterministic" => false,
            "comment" => "Encrypted API secret token"
          }
        }
      }
    }
  end

  def teardown
    MechaEncrypt.reset_configuration!
  end

  def test_version_is_defined
    refute_nil MechaEncrypt::VERSION
    assert_equal MechaEncrypt::VERSION, MechaEncrypt::Version
  end

  def test_registry_parses_tables_columns_and_ignored_patterns
    registry = MechaEncrypt::Registry.new(@sample_config)

    assert registry.table_registered?("users")
    assert registry.column_registered?("users", "id")
    assert registry.column_registered?("users", "secret_token")
    refute registry.column_registered?("users", "unknown")

    assert registry.table_ignored?("solid_queue_jobs")
    refute registry.table_ignored?("users")

    enc_cols = registry.encrypted_columns
    assert_equal 1, enc_cols.size
    assert_equal "secret_token", enc_cols.first[:column]
  end

  def test_registry_validates_schema
    assert_raises(MechaEncrypt::ConfigurationError) do
      MechaEncrypt::Registry.new({ "other" => {} })
    end

    assert_raises(MechaEncrypt::ConfigurationError) do
      MechaEncrypt::Registry.new({
        "tables" => {
          "users" => {
            "id" => { "encrypted" => "yes" }
          }
        }
      })
    end

    assert_raises(MechaEncrypt::ConfigurationError) do
      MechaEncrypt::Registry.new({
        "tables" => {
          "users" => {
            "id" => { "encrypted" => false, "deterministic" => true }
          }
        }
      })
    end
  end

  def test_static_auditor_validates_comments_and_schema_parity
    registry = MechaEncrypt::Registry.new(@sample_config)
    conn = FakeConnection.new(
      "users" => [
        FakeColumn.new("id", "uuid"),
        FakeColumn.new("email", "varchar"),
        FakeColumn.new("unmapped_col", "varchar")
      ],
      "solid_queue_jobs" => [
        FakeColumn.new("id", "bigint")
      ]
    )

    auditor = MechaEncrypt::Auditor::Static.new(registry, MechaEncrypt.configuration, connection: conn)
    result = auditor.audit

    refute result.success?
    assert_includes result.unmapped_columns, "users.unmapped_col"
    assert_includes result.dead_columns, "users.secret_token"

    # Comment validation checks
    assert_nil auditor.validate_comment("Primary key UUID identifier for joins")
    refute_nil auditor.validate_comment("")
    refute_nil auditor.validate_comment("short")
    refute_nil auditor.validate_comment("todo")
    refute_nil auditor.validate_comment("aaaaaaaaaaaa")
  end

  def test_prober_detects_non_deterministic_encrypted_column_in_db_index
    registry = MechaEncrypt::Registry.new(@sample_config)
    conn = FakeConnection.new(
      { "users" => [FakeColumn.new("secret_token", "varchar")] },
      { "users" => [FakeIndex.new("index_users_on_secret_token", ["secret_token"])] }
    )

    prober = MechaEncrypt::Auditor::Prober.new(registry: registry, connection: conn)
    idx_result = prober.probe_index_safety

    refute idx_result.success?
    assert_equal 1, idx_result.index_failures.size
    assert_equal "secret_token", idx_result.index_failures.first.column
  end
end
