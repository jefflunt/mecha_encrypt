# frozen_string_literal: true

require "yaml"

module MechaEncrypt
  class Registry
    attr_reader :tables, :ignored_tables, :colorization

    def initialize(config_path_or_hash = nil)
      @tables = {}
      @ignored_tables = []
      @colorization = {}

      if config_path_or_hash.is_a?(Hash)
        load_from_hash(config_path_or_hash)
      elsif config_path_or_hash
        load_from_file(config_path_or_hash)
      end
    end

    def load_from_file(path)
      raise ConfigurationError, "Encryption configuration file missing: #{path}" unless File.exist?(path)

      data = begin
        YAML.load_file(path)
      rescue => e
        raise ConfigurationError, "Invalid YAML syntax in #{path}: #{e.message}"
      end

      load_from_hash(data)
    end

    def load_from_hash(data)
      unless data.is_a?(Hash) && data.key?("tables") && (data["tables"].is_a?(Hash) || data["tables"].is_a?(Array))
        raise ConfigurationError, "Encryption config must have a top-level 'tables' mapping or list"
      end

      @ignored_tables = parse_ignored_tables(data["ignored_tables"] || [])
      @tables = parse_tables(data["tables"])

      if data["debug_colorization"].is_a?(Hash)
        @colorization = data["debug_colorization"].transform_keys(&:to_sym).transform_values do |v|
          v.to_s.sub(/^:/, "").to_sym
        end
      end

      @ignored_tables.freeze
      @tables.freeze
      self
    end

    def table_registered?(table_name)
      @tables.key?(table_name.to_s)
    end

    def table_columns(table_name)
      @tables[table_name.to_s] || {}
    end

    def column_entry(table_name, column_name)
      table_columns(table_name)[column_name.to_s]
    end

    def column_registered?(table_name, column_name)
      !column_entry(table_name, column_name).nil?
    end

    def ignored_table_entry_for(table_name)
      t_name = table_name.to_s
      @ignored_tables.find do |entry|
        File.fnmatch?(entry[:pattern], t_name)
      end
    end

    def table_ignored?(table_name)
      !ignored_table_entry_for(table_name).nil?
    end

    def encrypted_columns
      result = []
      @tables.each_value do |cols|
        cols.each_value do |col_entry|
          result << col_entry if col_entry[:encrypted]
        end
      end
      result
    end

    private

    def parse_ignored_tables(raw_list)
      unless raw_list.is_a?(Array)
        raise ConfigurationError, "'ignored_tables' must be an Array"
      end

      seen_patterns = {}
      raw_list.each_with_index.map do |item, idx|
        unless item.is_a?(Hash)
          raise ConfigurationError, "ignored_tables entry at index #{idx} must be a Hash"
        end

        pattern = (item["pattern"] || item["table"]).to_s.strip
        if pattern.empty?
          raise ConfigurationError, "ignored_tables entry at index #{idx} must specify a non-empty 'pattern' or 'table'"
        end

        if seen_patterns.key?(pattern)
          raise ConfigurationError, "Duplicate ignored_tables pattern '#{pattern}'"
        end
        seen_patterns[pattern] = true

        {
          pattern: pattern,
          comment: item["comment"]&.to_s&.strip
        }.freeze
      end
    end

    def parse_tables(raw_tables)
      parsed = {}

      if raw_tables.is_a?(Hash)
        raw_tables.each do |table_name, raw_columns|
          t_name = table_name.to_s.strip
          if t_name.empty?
            raise ConfigurationError, "Table name in 'tables' cannot be empty"
          end
          parsed[t_name] = parse_columns_for_table(t_name, raw_columns)
        end
      elsif raw_tables.is_a?(Array)
        raw_tables.each_with_index do |entry, idx|
          unless entry.is_a?(Hash) && entry["table"].is_a?(String) && !entry["table"].strip.empty?
            raise ConfigurationError, "Table entry at index #{idx} must be a Hash with a non-empty 'table' name"
          end
          t_name = entry["table"].strip
          if parsed.key?(t_name)
            raise ConfigurationError, "Duplicate table entry '#{t_name}' in encryption configuration"
          end
          parsed[t_name] = parse_columns_for_table(t_name, entry["columns"])
        end
      end

      parsed
    end

    def parse_columns_for_table(table_name, raw_columns)
      unless raw_columns.is_a?(Hash)
        raise ConfigurationError, "Columns for table '#{table_name}' must be a Hash mapping column names to definitions"
      end

      cols = {}
      raw_columns.each do |col_name, spec|
        c_name = col_name.to_s.strip
        if c_name.empty?
          raise ConfigurationError, "Column name in table '#{table_name}' cannot be empty"
        end

        unless spec.is_a?(Hash)
          raise ConfigurationError, "Definition for '#{table_name}.#{c_name}' must be a Hash"
        end

        unless [true, false].include?(spec["encrypted"])
          raise ConfigurationError,
                "Definition for '#{table_name}.#{c_name}' must explicitly specify boolean 'encrypted: true' or 'encrypted: false'"
        end

        encrypted = spec["encrypted"]
        deterministic = if spec.key?("deterministic")
          unless [true, false].include?(spec["deterministic"])
            raise ConfigurationError,
                  "Definition for '#{table_name}.#{c_name}' has invalid 'deterministic' value (must be boolean true or false)"
          end
          spec["deterministic"]
        else
          false
        end

        if !encrypted && deterministic
          raise ConfigurationError,
                "Definition for '#{table_name}.#{c_name}' cannot specify 'deterministic: true' when 'encrypted: false'"
        end

        cols[c_name] = {
          table: table_name,
          column: c_name,
          encrypted: encrypted,
          deterministic: deterministic,
          comment: spec["comment"]&.to_s&.strip
        }.freeze
      end

      cols.freeze
    end
  end
end
