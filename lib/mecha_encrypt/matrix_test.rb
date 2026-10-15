# frozen_string_literal: true

unless defined?(ActionDispatch::IntegrationTest)
  app_test_helper = File.join(Dir.pwd, "test/test_helper.rb")
  require app_test_helper if File.exist?(app_test_helper)
end
require "mecha_encrypt"

module MechaEncrypt
  class MatrixTest < ActionDispatch::IntegrationTest
    setup do
      if MechaEncrypt.configuration.test_setup
        instance_exec(&MechaEncrypt.configuration.test_setup)
      end
    end

    teardown do
      if MechaEncrypt.configuration.test_teardown
        instance_exec(&MechaEncrypt.configuration.test_teardown)
      end
    end

    test "static database and model encryption audit passes with zero violations" do
      result = MechaEncrypt::Auditor::Static.new.audit

      assert_empty result.unmapped_tables, "Unmapped tables: #{result.unmapped_tables.inspect}"
      assert_empty result.unmapped_columns, "Unmapped columns: #{result.unmapped_columns.inspect}"
      assert_empty result.unencrypted_in_model, "Columns registered as encrypted but missing from model: #{result.unencrypted_in_model.inspect}"
      assert_empty result.undeclared_encrypted_in_model, "Columns encrypted in model but marked unencrypted in YAML: #{result.undeclared_encrypted_in_model.inspect}"
      assert_empty result.mode_mismatches, "Encryption determinism mismatches: #{result.mode_mismatches.inspect}"
      assert_empty result.invalid_comments, "Invalid or missing comments: #{result.invalid_comments.inspect}"
      assert_empty result.dead_tables, "Dead tables in YAML: #{result.dead_tables.inspect}"
      assert_empty result.dead_columns, "Dead columns in YAML: #{result.dead_columns.inspect}"
      assert_empty result.dead_ignored_patterns, "Dead ignored_tables patterns: #{result.dead_ignored_patterns.inspect}"
      assert result.success?
    end

    test "behavioral prober verifies database index safety for all encrypted columns" do
      prober = MechaEncrypt::Auditor::Prober.new
      idx_result = prober.probe_index_safety

      assert idx_result.success?, "MechaEncrypt index safety check failed:\n" +
        idx_result.index_failures.map { |f| "  - [#{f.table}.#{f.column}] #{f.message}" }.join("\n")
    end

    test "behavioral prober catches non-deterministic encrypted column covered by a database index" do
      raw = YAML.load_file(MechaEncrypt.configuration.config_path)
      indexed_table, indexed_col = find_first_indexed_table_and_column
      return unless indexed_table && indexed_col

      raw["tables"][indexed_table][indexed_col] = {
        "encrypted" => true,
        "deterministic" => false
      }

      registry = MechaEncrypt::Registry.new(raw)
      prober = MechaEncrypt::Auditor::Prober.new(registry: registry)
      idx_result = prober.probe_index_safety

      refute idx_result.success?
      assert idx_result.index_failures.any? { |f| f.table == indexed_table && f.column == indexed_col }
    end

    def self.define_encrypt_matrix_tests!
      return if @encrypt_matrix_tests_defined
      @encrypt_matrix_tests_defined = true

      # 1. One test per encrypted column for type serialization, envelope format, and determinism
      MechaEncrypt.registry.encrypted_columns.each do |entry|
        table_name = entry[:table]
        col_name = entry[:column]

        test "behavioral ciphertext serialization and determinism for #{table_name}.#{col_name}" do
          prober = MechaEncrypt::Auditor::Prober.new
          result = prober.probe_single_column_type(entry)

          assert result.success?, "MechaEncrypt column type probe failed for #{table_name}.#{col_name}:\n" +
            result.failures.map { |f| "  - [#{f.table}.#{f.column}] #{f.message}" }.join("\n")
        end
      end

      # 2. One test per table with encrypted columns for raw SQL persisted record verification
      encrypted_by_table = MechaEncrypt.registry.encrypted_columns.group_by { |e| e[:table] }
      encrypted_by_table.each_key do |table_name|
        test "behavioral raw SQL ciphertext persistence for table #{table_name}" do
          records_proc = MechaEncrypt.configuration.test_records
          assert_not_nil records_proc, "MechaEncrypt.configuration.test_records must be configured for behavioral matrix testing"

          records_by_table = instance_exec(&records_proc)
          prober = MechaEncrypt::Auditor::Prober.new
          result = prober.probe_single_table_persisted_record(table_name, records_by_table)

          assert result.success?, "MechaEncrypt raw SQL persistence probe failed for #{table_name}:\n" +
            result.failures.map { |f| "  - [#{f.table}.#{f.column}] #{f.message}" }.join("\n")
        end
      end
    end

    define_encrypt_matrix_tests!

    private

    def find_first_indexed_table_and_column
      conn = ActiveRecord::Base.connection
      MechaEncrypt.registry.tables.each_key do |table_name|
        next unless conn.table_exists?(table_name)

        indexes = conn.indexes(table_name)
        indexes.each do |idx|
          col = idx.columns.is_a?(Array) ? idx.columns.first : idx.columns.to_s
          if col.present? && MechaEncrypt.registry.column_registered?(table_name, col)
            return [table_name, col.to_s]
          end
        end
      end
      nil
    end
  end
end
