# frozen_string_literal: true

require "tiny_color"
require_relative "../mecha_encrypt"

class String
  def dark_grey
    respond_to?(:grey) ? grey : self
  end unless method_defined?(:dark_grey)

  def dark_gray
    respond_to?(:gray) ? gray : self
  end unless method_defined?(:dark_gray)
end

desc "Print all database tables and columns in alphabetical order with their MechaEncrypt status"
task mecha_encrypt: :environment do
  auditor = MechaEncrypt::Auditor::Static.new
  result = auditor.audit
  colors = MechaEncrypt.configuration.debug_colorization

  colorize = ->(text, key) {
    color = colors[key]
    if color && text.respond_to?(color)
      text.send(color)
    else
      text
    end
  }

  all_cols = result.all_column_audits
  max_col_len = [all_cols.map { |c| c.column.to_s.length }.max || 6, 6].max
  max_type_len = [all_cols.map { |c| c.sql_type.to_s.length }.max || 8, 8].max
  max_status_len = 25

  puts "=== MechaEncrypt Database Column Encryption Registry ==="

  result.table_audits.each do |table_audit|
    model_label = table_audit.model ? " (#{table_audit.model})" : ""
    puts "\n#{table_audit.table}#{model_label}"

    if table_audit.ignored
      padded_status = sprintf("%-#{max_status_len}s", "IGNORED TABLE")
      puts sprintf(
        "  %-#{max_col_len}s  %-#{max_type_len}s  %s  %s",
        "*",
        "-",
        colorize.call(padded_status, :ignored),
        table_audit.ignore_comment
      )
      next
    end

    puts sprintf(
      "  %-#{max_col_len}s  %-#{max_type_len}s  %-#{max_status_len}s  %s",
      "Column",
      "SQL Type",
      "Encryption Status",
      "Comment / Details"
    )

    table_audit.columns.each do |col|
      padded_col = sprintf("%-#{max_col_len}s", col.column)
      padded_type = sprintf("%-#{max_type_len}s", col.sql_type)

      status_label = case col.status
      when :encrypted
        "ENCRYPTED"
      when :deterministic
        "ENCRYPTED (DETERMINISTIC)"
      when :unencrypted
        "NOT ENCRYPTED"
      when :unmapped
        "UNMAPPED"
      when :violation
        "VIOLATION"
      else
        col.status.to_s.upcase
      end

      padded_status = sprintf("%-#{max_status_len}s", status_label)

      detail = if col.status == :violation || col.status == :unmapped
        col.violation_message
      else
        col.comment.presence || "-"
      end

      puts sprintf(
        "  %s  %s  %s  %s",
        colorize.call(padded_col, col.status),
        padded_type,
        colorize.call(padded_status, col.status),
        detail
      )
    end
  end
end

namespace :mecha_encrypt do
  namespace :verify do
    desc "Statically verify database column encryption registry parity, model declarations, and comments"
    task static: :environment do
      puts "Running MechaEncrypt static database & model encryption audit..."
      auditor = MechaEncrypt::Auditor::Static.new
      result = auditor.audit

      audited_tables_count = result.audited_tables.size
      ignored_tables_count = result.ignored_tables.size
      all_cols = result.all_column_audits
      encrypted_count = all_cols.count { |c| c.status == :encrypted }
      deterministic_count = all_cols.count { |c| c.status == :deterministic }
      unencrypted_count = all_cols.count { |c| c.status == :unencrypted }

      puts "  -> #{audited_tables_count} tables audited (#{ignored_tables_count} framework/engine tables ignored via pattern)"
      puts "  -> #{all_cols.size} columns audited (#{encrypted_count} encrypted, #{deterministic_count} deterministic, #{unencrypted_count} unencrypted)"

      if result.unmapped_tables.any?
        puts "\nERROR: Found #{result.unmapped_tables.size} unregistered table(s) missing from config/mecha_encrypt.yml:".light_red
        result.unmapped_tables.each { |t| puts "  - #{t}" }
      end

      if result.unmapped_columns.any?
        puts "\nERROR: Found #{result.unmapped_columns.size} unregistered database column(s) missing from config/mecha_encrypt.yml:".light_red
        result.unmapped_columns.each { |c| puts "  - #{c}" }
      end

      if result.unencrypted_in_model.any?
        puts "\nERROR: Found #{result.unencrypted_in_model.size} column(s) registered as encrypted in YAML but NOT encrypted on the model:".light_red
        result.unencrypted_in_model.each { |err| puts "  - #{err}" }
      end

      if result.undeclared_encrypted_in_model.any?
        puts "\nERROR: Found #{result.undeclared_encrypted_in_model.size} column(s) encrypted on the model but marked unencrypted in YAML:".light_red
        result.undeclared_encrypted_in_model.each { |err| puts "  - #{err}" }
      end

      if result.mode_mismatches.any?
        puts "\nERROR: Found #{result.mode_mismatches.size} encryption determinism mismatch(es) between YAML and model:".light_red
        result.mode_mismatches.each { |err| puts "  - #{err}" }
      end

      if result.invalid_comments.any?
        puts "\nERROR: Found #{result.invalid_comments.size} non-encrypted field/table entry(ies) without a valid comment:".light_red
        result.invalid_comments.each { |err| puts "  - #{err}" }
      end

      if result.dead_tables.any?
        puts "\nERROR: Found #{result.dead_tables.size} dead/stale table(s) in config/mecha_encrypt.yml:".light_red
        result.dead_tables.each { |t| puts "  - #{t}" }
      end

      if result.dead_columns.any?
        puts "\nERROR: Found #{result.dead_columns.size} dead/stale column(s) in config/mecha_encrypt.yml:".light_red
        result.dead_columns.each { |c| puts "  - #{c}" }
      end

      if result.dead_ignored_patterns.any?
        puts "\nERROR: Found #{result.dead_ignored_patterns.size} dead ignored_tables pattern(s) matching 0 tables:".light_red
        result.dead_ignored_patterns.each { |p| puts "  - #{p}" }
      end

      if result.success?
        puts "\n✓ Static database encryption audit passed: 0 unregistered columns, 0 model mismatches, 0 missing comments.".green
      else
        abort("\n✗ Static database encryption audit failed. Please resolve the errors above.")
      end
    end

    desc "Run behavioral ciphertext round-trip and index safety test suite"
    task behavioral: :environment do
      puts "Running MechaEncrypt behavioral encryption & index safety test suite..."
      matrix_test_path = File.expand_path("../mecha_encrypt/matrix_test.rb", __dir__)
      system({ "MECHA_MATRIX_STANDALONE" => "1" }, "bin/rails", "test", matrix_test_path) || abort("Behavioral encryption verification failed.")
    end
  end

  desc "Run both static schema/model verification and behavioral ciphertext verification"
  task verify: %w[verify:static verify:behavioral]
end
