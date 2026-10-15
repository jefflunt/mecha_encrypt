# frozen_string_literal: true

module MechaEncrypt
  module Errors
    class Error < StandardError; end
    class ConfigurationError < Error; end
  end

  Error = Errors::Error
  ConfigurationError = Errors::ConfigurationError
end
