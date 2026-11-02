# frozen_string_literal: true

require "rails/railtie"

module MechaEncrypt
  class Railtie < Rails::Railtie
    initializer "mecha_encrypt.active_record" do
      ActiveSupport.on_load(:active_record) do
        include MechaEncrypt::Model
      end
    end

    rake_tasks do
      load File.expand_path("../tasks/mecha_encrypt.rake", __dir__)
    end
  end
end
