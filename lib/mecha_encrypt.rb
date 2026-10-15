# frozen_string_literal: true

require_relative "mecha_encrypt/version"
require_relative "mecha_encrypt/errors"
require_relative "mecha_encrypt/configuration"
require_relative "mecha_encrypt/registry"
require_relative "mecha_encrypt/auditor/static"
require_relative "mecha_encrypt/auditor/prober"
require_relative "mecha_encrypt/railtie" if defined?(Rails::Railtie)

module MechaEncrypt
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
      reload!
    end

    def reset_configuration!
      @configuration = Configuration.new
      @registry = nil
    end

    def registry
      @registry ||= Registry.new(configuration.config_path)
    end

    def reload!
      @registry = Registry.new(configuration.config_path)
      if @registry.colorization.any?
        @configuration.debug_colorization = @configuration.debug_colorization.merge(@registry.colorization)
      end
      @registry
    end
  end
end
