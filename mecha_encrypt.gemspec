# frozen_string_literal: true

require_relative "lib/mecha_encrypt/version"

Gem::Specification.new do |s|
  s.name        = "mecha_encrypt"
  s.version     = MechaEncrypt::VERSION
  s.summary     = "Explicit database column encryption registry and auditing for Rails"
  s.description = "MechaEncrypt enforces database column encryption parity in Rails applications via a YAML schema registry, static schema-to-model auditing, and behavioral ciphertext & index safety probing."
  s.authors     = ["Jeff Lunt"]
  s.email       = ["jefflunt@gmail.com"]
  s.homepage    = "https://github.com/jefflunt/mecha_encrypt"
  s.license     = "MIT"

  s.required_ruby_version = ">= 3.2.0"

  s.require_paths = ["lib"]
  s.files         = Dir["lib/**/*", "LICENSE", "README.md", "Rakefile"]

  s.add_dependency "activesupport", ">= 7.0"
  s.add_dependency "tiny_color"
end
