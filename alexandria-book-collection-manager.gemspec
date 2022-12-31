# frozen_string_literal: true

require_relative "lib/alexandria/version"

Gem::Specification.new do |spec|
  spec.name = "alexandria-book-collection-manager"
  spec.version = Alexandria::VERSION
  spec.authors = [
    "Alexander McCormmach",
    "Aymeric Nys",
    "Cathal Mc Ginley",
    "Claudio Belotti",
    "Constantine Evans",
    "Dafydd Harries",
    "Javier Fernandez-Sanguino Pena",
    "Joseph Method",
    "Kevin Schultz",
    "Laurent Sansonetti",
    "Marco Costantini",
    "Mathieu Leduc-Hamel",
    "Matijs van Zuijlen",
    "Owain Evans",
    "Pascal Terjan",
    "Rene Samselnig",
    "Robby Stephenson",
    "Sun Ning",
    "Takayuki Kusano",
    "Timothy Malone",
    "Zachary P. Landau"
  ]
  spec.email = ["matijs@matijs.net"]

  spec.summary = "GNOME application for managing collections of books"

  spec.homepage = "http://www.github.com/mvz/alexandria-book-collection-manager"
  spec.license = "GPL-2.0+"

  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = `git ls-files -z`.split("\0") |
    ["lib/alexandria/default_preferences.rb"]

  spec.executables = ["alexandria"]

  spec.require_paths = ["lib"]
  spec.rdoc_options = ["--main", "README.md"]

  spec.add_runtime_dependency "gettext", ["~> 3.1"]
  spec.add_runtime_dependency "gstreamer", ["~> 4.0.2"]
  spec.add_runtime_dependency "gtk3", ["~> 4.0.2"]
  spec.add_runtime_dependency "htmlentities", ["~> 4.3"]
  spec.add_runtime_dependency "image_size", ["~> 3.0"]
  spec.add_runtime_dependency "marc", ">= 1.0", "< 1.3"
  spec.add_runtime_dependency "nokogiri", ["~> 1.11"]
  spec.add_runtime_dependency "zoom", ["~> 0.5.0"]

  spec.add_development_dependency "gnome_app_driver", "~> 0.3.2"
  spec.add_development_dependency "rake", ["~> 13.0"]
  spec.add_development_dependency "rspec", ["~> 3.0"]
  spec.add_development_dependency "rubocop", "~> 1.42"
  spec.add_development_dependency "rubocop-i18n", "~> 3.0"
  spec.add_development_dependency "rubocop-performance", "~> 1.15"
  spec.add_development_dependency "rubocop-rake", "~> 0.6.0"
  spec.add_development_dependency "rubocop-rspec", "~> 2.16"
  spec.add_development_dependency "webmock", "~> 3.9"
end
