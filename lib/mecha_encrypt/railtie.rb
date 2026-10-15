# frozen_string_literal: true

require "rails/railtie"

module MechaEncrypt
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.expand_path("../tasks/mecha_encrypt.rake", __dir__)
    end
  end
end
