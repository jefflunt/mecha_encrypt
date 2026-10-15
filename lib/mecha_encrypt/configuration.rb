# frozen_string_literal: true

module MechaEncrypt
  class Configuration
    DEFAULT_INTERNAL_TABLES = %w[
      schema_migrations
      ar_internal_metadata
    ].freeze

    DEFAULT_FORBIDDEN_COMMENTS = %w[
      todo
      tbd
      n/a
      na
      none
      nil
      null
      unencrypted
      not_encrypted
      not\ encrypted
      fixme
      reason
      comment
      test
      ok
      yes
      no
      later
      skip
    ].freeze

    attr_accessor :config_path,
                  :base_model_class,
                  :internal_tables,
                  :min_comment_length,
                  :forbidden_comments,
                  :debug_colorization,
                  :test_setup,
                  :test_teardown,
                  :test_records

    def initialize
      @config_path = if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
        Rails.root.join("config/mecha_encrypt.yml")
      else
        "config/mecha_encrypt.yml"
      end
      @base_model_class = "ApplicationRecord"
      @internal_tables = DEFAULT_INTERNAL_TABLES.dup
      @min_comment_length = 10
      @forbidden_comments = DEFAULT_FORBIDDEN_COMMENTS.dup
      @debug_colorization = {
        encrypted: :green,
        deterministic: :light_cyan,
        unencrypted: :light_purple,
        ignored: :yellow,
        violation: :light_red,
        unmapped: :dark_grey
      }
      @test_setup = nil
      @test_teardown = nil
      @test_records = nil
    end

    def configure_test_matrix(records: nil, setup: nil, teardown: nil)
      @test_records = records if records
      @test_setup = setup if setup
      @test_teardown = teardown if teardown
    end
  end
end
