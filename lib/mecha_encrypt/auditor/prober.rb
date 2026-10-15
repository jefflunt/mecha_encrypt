# frozen_string_literal: true

require "securerandom"

module MechaEncrypt
  module Auditor
    class Prober
      CipherFailure = Struct.new(:table, :column, :model, :message, keyword_init: true)
      IndexFailure = Struct.new(:table, :column, :index_name, :message, keyword_init: true)

      Result = Struct.new(
        :probed_columns_count,
        :probed_records_count,
        :cipher_failures,
        :index_failures,
        keyword_init: true
      ) do
        def success?
          cipher_failures.empty? && index_failures.empty?
        end

        def failures
          cipher_failures + index_failures
        end
      end

      def initialize(registry: MechaEncrypt.registry, configuration: MechaEncrypt.configuration, connection: nil)
        @registry = registry
        @configuration = configuration
        @connection = connection
      end

      # Verify that non-deterministic encrypted columns do not have broken B-tree / unique DB indexes
      def probe_index_safety
        index_failures = []
        conn = db_connection

        @registry.tables.each do |table_name, cols|
          next unless conn.table_exists?(table_name)

          indexes = conn.indexes(table_name)
          cols.each_value do |entry|
            next unless entry[:encrypted] && !entry[:deterministic]

            col_name = entry[:column]
            indexes.each do |idx|
              covered = if idx.columns.is_a?(Array)
                idx.columns.map(&:to_s).include?(col_name)
              else
                idx.columns.to_s.match?(/\b#{Regexp.escape(col_name)}\b/)
              end

              if covered
                index_failures << IndexFailure.new(
                  table: table_name,
                  column: col_name,
                  index_name: idx.name,
                  message: "Non-deterministic encrypted column '#{table_name}.#{col_name}' is covered by DB index '#{idx.name}'. Non-deterministic encryption uses random IVs, breaking index lookups and uniqueness constraints."
                )
              end
            end
          end
        end

        Result.new(
          probed_columns_count: @registry.encrypted_columns.size,
          probed_records_count: 0,
          cipher_failures: [],
          index_failures: index_failures
        )
      end

      # Verify type serialization, ciphertext envelope, round-trip decryption, and deterministic vs non-deterministic IV behavior
      def probe_encryption_types
        ensure_models_loaded!
        cipher_failures = []
        models_by_table = discover_models_by_table
        probed_count = 0

        @registry.encrypted_columns.each do |entry|
          res = probe_single_column_type(entry, models_by_table: models_by_table)
          probed_count += res.probed_columns_count
          cipher_failures.concat(res.cipher_failures)
        end

        Result.new(
          probed_columns_count: probed_count,
          probed_records_count: 0,
          cipher_failures: cipher_failures,
          index_failures: []
        )
      end

      def probe_single_column_type(entry, models_by_table: nil)
        ensure_models_loaded!
        models_map = models_by_table || discover_models_by_table
        cipher_failures = []

        table_name = entry[:table]
        col_name = entry[:column]
        model_klass = models_map[table_name]

        if model_klass.nil?
          cipher_failures << CipherFailure.new(
            table: table_name,
            column: col_name,
            model: nil,
            message: "No ActiveRecord model found for table '#{table_name}'"
          )
        else
          attr_type = model_klass.type_for_attribute(col_name)
          if !attr_type.respond_to?(:serialize) || !attr_type.respond_to?(:deserialize)
            cipher_failures << CipherFailure.new(
              table: table_name,
              column: col_name,
              model: model_klass.name,
              message: "Attribute type for #{model_klass.name}##{col_name} does not support serialize/deserialize"
            )
          else
            probe_plaintext = "mecha_secret_#{table_name}_#{col_name}_#{SecureRandom.hex(8)}"
            cipher1 = attr_type.serialize(probe_plaintext)
            cipher2 = attr_type.serialize(probe_plaintext)

            if !cipher1.is_a?(String) || cipher1.include?(probe_plaintext) || !cipher1.start_with?("{\"p\":")
              cipher_failures << CipherFailure.new(
                table: table_name,
                column: col_name,
                model: model_klass.name,
                message: "Serialized value for #{model_klass.name}##{col_name} is not valid ActiveRecord::Encryption ciphertext"
              )
            else
              decrypted = attr_type.deserialize(cipher1)
              if decrypted != probe_plaintext
                cipher_failures << CipherFailure.new(
                  table: table_name,
                  column: col_name,
                  model: model_klass.name,
                  message: "Round-trip decryption failed for #{model_klass.name}##{col_name}: expected #{probe_plaintext.inspect}, got #{decrypted.inspect}"
                )
              end

              if entry[:deterministic] && cipher1 != cipher2
                cipher_failures << CipherFailure.new(
                  table: table_name,
                  column: col_name,
                  model: model_klass.name,
                  message: "Deterministic encrypted column #{model_klass.name}##{col_name} produced different ciphertexts for identical plaintext"
                )
              elsif !entry[:deterministic] && cipher1 == cipher2
                cipher_failures << CipherFailure.new(
                  table: table_name,
                  column: col_name,
                  model: model_klass.name,
                  message: "Non-deterministic encrypted column #{model_klass.name}##{col_name} produced identical ciphertexts for identical plaintext (missing random IV)"
                )
              end
            end
          end
        end

        Result.new(
          probed_columns_count: 1,
          probed_records_count: 0,
          cipher_failures: cipher_failures,
          index_failures: []
        )
      end

      # Verify raw SQL storage in PostgreSQL for persisted model records
      def probe_persisted_records(records_by_table)
        cipher_failures = []
        probed_records = 0
        normalized = normalize_records_map(records_by_table)

        encrypted_by_table = @registry.encrypted_columns.group_by { |e| e[:table] }

        encrypted_by_table.each_key do |table_name|
          res = probe_single_table_persisted_record(table_name, normalized)
          probed_records += res.probed_records_count
          cipher_failures.concat(res.cipher_failures)
        end

        Result.new(
          probed_columns_count: @registry.encrypted_columns.size,
          probed_records_count: probed_records,
          cipher_failures: cipher_failures,
          index_failures: []
        )
      end

      def probe_single_table_persisted_record(table_name, records_by_table)
        cipher_failures = []
        probed_records = 0
        conn = db_connection
        normalized = normalize_records_map(records_by_table)

        entries = @registry.encrypted_columns.select { |e| e[:table] == table_name.to_s }
        record = normalized[table_name.to_s]

        if record.nil?
          cipher_failures << CipherFailure.new(
            table: table_name.to_s,
            column: entries.map { |e| e[:column] }.join(", "),
            model: nil,
            message: "Missing test record for table '#{table_name}' with encrypted columns"
          )
        else
          probed_records = 1
          entries.each do |entry|
            col_name = entry[:column]
            plaintext_val = record.public_send(col_name).to_s

            if plaintext_val.empty?
              cipher_failures << CipherFailure.new(
                table: table_name.to_s,
                column: col_name,
                model: record.class.name,
                message: "Test record for #{record.class.name}##{col_name} has an empty plaintext value; cannot verify ciphertext storage"
              )
              next
            end

            sql = "SELECT #{conn.quote_column_name(col_name)} FROM #{conn.quote_table_name(table_name)} WHERE id = #{conn.quote(record.id)}"
            raw_db_value = conn.select_value(sql).to_s

            if raw_db_value.empty? || raw_db_value.include?(plaintext_val) || !raw_db_value.start_with?("{\"p\":")
              cipher_failures << CipherFailure.new(
                table: table_name.to_s,
                column: col_name,
                model: record.class.name,
                message: "PLAINTEXT LEAK IN DB: Raw SQL value for #{table_name}.#{col_name} (id=#{record.id}) is not encrypted! Got: #{raw_db_value.inspect}"
              )
            end

            reloaded_val = record.class.find(record.id).public_send(col_name).to_s
            if reloaded_val != plaintext_val
              cipher_failures << CipherFailure.new(
                table: table_name.to_s,
                column: col_name,
                model: record.class.name,
                message: "Reloaded value for #{table_name}.#{col_name} (id=#{record.id}) did not decrypt back to #{plaintext_val.inspect} (got #{reloaded_val.inspect})"
              )
            end
          end
        end

        Result.new(
          probed_columns_count: entries.size,
          probed_records_count: probed_records,
          cipher_failures: cipher_failures,
          index_failures: []
        )
      end

      def probe_all(records_by_table = nil)
        idx_res = probe_index_safety
        type_res = probe_encryption_types
        rec_res = records_by_table ? probe_persisted_records(records_by_table) : nil

        Result.new(
          probed_columns_count: type_res.probed_columns_count,
          probed_records_count: rec_res ? rec_res.probed_records_count : 0,
          cipher_failures: type_res.cipher_failures + (rec_res ? rec_res.cipher_failures : []),
          index_failures: idx_res.index_failures
        )
      end

      private

      def db_connection
        @connection || ActiveRecord::Base.connection
      end

      def ensure_models_loaded!
        if defined?(Rails) && Rails.respond_to?(:application) && Rails.application
          Rails.application.eager_load!
        end
      end

      def discover_models_by_table
        base_class_name = @configuration.base_model_class.to_s
        base_class = base_class_name.safe_constantize
        return {} unless base_class

        models = {}
        base_class.descendants.reject(&:abstract_class?).each do |klass|
          next unless klass.name.present? && !klass.name.include?("#<")
          next unless klass.table_name.present?

          models[klass.table_name] ||= klass
        end
        models
      end

      def normalize_records_map(records_hash)
        records_hash.each_with_object({}) do |(k, v), h|
          key = if k.is_a?(Class) && k.respond_to?(:table_name)
            k.table_name.to_s
          else
            k.to_s
          end
          h[key] = v
        end
      end
    end
  end
end
