# frozen_string_literal: true

require "set"

module MechaEncrypt
  module Auditor
    class Static
      ColumnAudit = Struct.new(
        :table,
        :column,
        :sql_type,
        :model,
        :status,
        :encrypted,
        :deterministic,
        :comment,
        :violation_message,
        keyword_init: true
      )

      TableAudit = Struct.new(
        :table,
        :model,
        :ignored,
        :ignore_comment,
        :registered,
        :columns,
        keyword_init: true
      )

      Result = Struct.new(
        :table_audits,
        :unmapped_tables,
        :unmapped_columns,
        :dead_tables,
        :dead_columns,
        :dead_ignored_patterns,
        :unencrypted_in_model,
        :undeclared_encrypted_in_model,
        :mode_mismatches,
        :invalid_comments,
        keyword_init: true
      ) do
        def success?
          unmapped_tables.empty? &&
            unmapped_columns.empty? &&
            dead_tables.empty? &&
            dead_columns.empty? &&
            dead_ignored_patterns.empty? &&
            unencrypted_in_model.empty? &&
            undeclared_encrypted_in_model.empty? &&
            mode_mismatches.empty? &&
            invalid_comments.empty?
        end

        def audited_tables
          table_audits.reject(&:ignored)
        end

        def ignored_tables
          table_audits.select(&:ignored)
        end

        def all_column_audits
          audited_tables.flat_map(&:columns)
        end
      end

      def initialize(registry = MechaEncrypt.registry, configuration = MechaEncrypt.configuration, connection: nil)
        @registry = registry
        @configuration = configuration
        @connection = connection
      end

      def audit
        ensure_models_loaded!

        conn = db_connection
        internal = Set.new(Array(@configuration.internal_tables).map(&:to_s))
        db_tables = conn.tables.reject { |t| internal.include?(t) }.sort
        models_by_table = discover_models_by_table

        table_audits = []
        unmapped_tables = []
        unmapped_columns = []
        dead_tables = []
        dead_columns = []
        dead_ignored_patterns = []
        unencrypted_in_model = []
        undeclared_encrypted_in_model = []
        mode_mismatches = []
        invalid_comments = []

        matched_ignore_patterns = Set.new

        # Validate comments on ignored_tables rules
        @registry.ignored_tables.each do |ignore_entry|
          comment_err = validate_comment(ignore_entry[:comment])
          if comment_err
            invalid_comments << "ignored_tables[#{ignore_entry[:pattern]}]: #{comment_err}"
          end
        end

        db_tables.each do |table_name|
          ignore_entry = @registry.ignored_table_entry_for(table_name)
          if ignore_entry
            matched_ignore_patterns << ignore_entry[:pattern]

            if @registry.table_registered?(table_name)
              dead_tables << "#{table_name} (table is matched by ignored_tables pattern '#{ignore_entry[:pattern]}' and must not also be listed in 'tables')"
            end

            table_audits << TableAudit.new(
              table: table_name,
              model: models_by_table[table_name]&.name,
              ignored: true,
              ignore_comment: ignore_entry[:comment],
              registered: false,
              columns: []
            )
            next
          end

          model_klass = models_by_table[table_name]
          table_registered = @registry.table_registered?(table_name)
          unmapped_tables << table_name unless table_registered

          db_cols = conn.columns(table_name).sort_by(&:name)
          db_col_names = Set.new(db_cols.map(&:name))

          # Check for dead columns in YAML for this table
          if table_registered
            @registry.table_columns(table_name).each_key do |reg_col|
              unless db_col_names.include?(reg_col)
                dead_columns << "#{table_name}.#{reg_col}"
              end
            end
          end

          col_audits = db_cols.map do |col|
            col_name = col.name
            actual_enc, actual_det = inspect_model_encryption(model_klass, col_name)
            entry = @registry.column_entry(table_name, col_name)

            if entry.nil?
              unmapped_columns << "#{table_name}.#{col_name}"
              ColumnAudit.new(
                table: table_name,
                column: col_name,
                sql_type: col.sql_type,
                model: model_klass&.name,
                status: :unmapped,
                encrypted: actual_enc,
                deterministic: actual_det,
                comment: nil,
                violation_message: "MISSING FROM config/mecha_encrypt.yml"
              )
            elsif entry[:encrypted] && !actual_enc
              msg = if model_klass
                "#{table_name}.#{col_name} is registered as encrypted in YAML, but #{model_klass.name} does not declare `encrypts :#{col_name}`"
              else
                "#{table_name}.#{col_name} is registered as encrypted in YAML, but no ActiveRecord model declares `encrypts :#{col_name}`"
              end
              unencrypted_in_model << msg
              ColumnAudit.new(
                table: table_name,
                column: col_name,
                sql_type: col.sql_type,
                model: model_klass&.name,
                status: :violation,
                encrypted: false,
                deterministic: false,
                comment: entry[:comment],
                violation_message: msg
              )
            elsif !entry[:encrypted] && actual_enc
              msg = "#{table_name}.#{col_name} is encrypted on #{model_klass.name} (`encrypts :#{col_name}`), but registered as `encrypted: false` in YAML"
              undeclared_encrypted_in_model << msg
              ColumnAudit.new(
                table: table_name,
                column: col_name,
                sql_type: col.sql_type,
                model: model_klass&.name,
                status: :violation,
                encrypted: true,
                deterministic: actual_det,
                comment: entry[:comment],
                violation_message: msg
              )
            elsif entry[:encrypted] && actual_enc && entry[:deterministic] != actual_det
              msg = "#{table_name}.#{col_name} deterministic mode mismatch: YAML declares deterministic=#{entry[:deterministic]}, but #{model_klass.name} has deterministic=#{actual_det}"
              mode_mismatches << msg
              ColumnAudit.new(
                table: table_name,
                column: col_name,
                sql_type: col.sql_type,
                model: model_klass&.name,
                status: :violation,
                encrypted: true,
                deterministic: actual_det,
                comment: entry[:comment],
                violation_message: msg
              )
            elsif !entry[:encrypted]
              comment_err = validate_comment(entry[:comment])
              if comment_err
                msg = "#{table_name}.#{col_name}: #{comment_err}"
                invalid_comments << msg
                ColumnAudit.new(
                  table: table_name,
                  column: col_name,
                  sql_type: col.sql_type,
                  model: model_klass&.name,
                  status: :violation,
                  encrypted: false,
                  deterministic: false,
                  comment: entry[:comment],
                  violation_message: msg
                )
              else
                ColumnAudit.new(
                  table: table_name,
                  column: col_name,
                  sql_type: col.sql_type,
                  model: model_klass&.name,
                  status: :unencrypted,
                  encrypted: false,
                  deterministic: false,
                  comment: entry[:comment],
                  violation_message: nil
                )
              end
            else
              ColumnAudit.new(
                table: table_name,
                column: col_name,
                sql_type: col.sql_type,
                model: model_klass&.name,
                status: actual_det ? :deterministic : :encrypted,
                encrypted: true,
                deterministic: actual_det,
                comment: entry[:comment],
                violation_message: nil
              )
            end
          end

          table_audits << TableAudit.new(
            table: table_name,
            model: model_klass&.name,
            ignored: false,
            ignore_comment: nil,
            registered: table_registered,
            columns: col_audits
          )
        end

        # Check for dead tables in YAML that do not exist in the DB
        db_table_set = Set.new(db_tables)
        @registry.tables.each_key do |reg_table|
          unless db_table_set.include?(reg_table)
            dead_tables << reg_table
          end
        end

        # Check for dead ignored_tables patterns that matched no DB tables
        @registry.ignored_tables.each do |ignore_entry|
          unless matched_ignore_patterns.include?(ignore_entry[:pattern])
            dead_ignored_patterns << ignore_entry[:pattern]
          end
        end

        Result.new(
          table_audits: table_audits,
          unmapped_tables: unmapped_tables.sort,
          unmapped_columns: unmapped_columns.sort,
          dead_tables: dead_tables.sort,
          dead_columns: dead_columns.sort,
          dead_ignored_patterns: dead_ignored_patterns.sort,
          unencrypted_in_model: unencrypted_in_model,
          undeclared_encrypted_in_model: undeclared_encrypted_in_model,
          mode_mismatches: mode_mismatches,
          invalid_comments: invalid_comments
        )
      end

      def validate_comment(comment)
        text = comment.to_s.strip
        if text.empty?
          return "Missing required comment explaining why this field/table is not encrypted"
        end

        min_len = @configuration.min_comment_length || 10
        if text.length < min_len
          return "Comment is too short (#{text.length} chars; minimum is #{min_len} chars): #{text.inspect}"
        end

        normalized = text.downcase.gsub(/[^a-z0-9\s\/]/, "").squeeze(" ").strip
        forbidden = Array(@configuration.forbidden_comments).map { |c| c.to_s.downcase.strip }
        if forbidden.include?(normalized) || forbidden.include?(text.downcase)
          return "Comment is a placeholder ('#{text}'); please provide a meaningful explanation"
        end

        # Reject strings made of a single repeated character or no alphabetic words
        words = text.scan(/[a-zA-Z]{2,}/)
        if words.size < 2 || text.gsub(/\s+/, "").chars.uniq.size < 4
          return "Comment must contain a meaningful multi-word explanation (got #{text.inspect})"
        end

        nil
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

          # Prefer primary application model if multiple classes share a table
          models[klass.table_name] ||= klass
        end
        models
      end

      def inspect_model_encryption(model_klass, column_name)
        return [false, false] unless model_klass && model_klass.respond_to?(:encrypted_attributes)

        enc_attrs = model_klass.encrypted_attributes
        return [false, false] if enc_attrs.blank?

        is_encrypted = enc_attrs.map(&:to_s).include?(column_name.to_s)
        return [false, false] unless is_encrypted

        attr_type = model_klass.type_for_attribute(column_name.to_s)
        is_deterministic = attr_type.respond_to?(:deterministic?) ? !!attr_type.deterministic? : false

        [true, is_deterministic]
      end
    end
  end
end
