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

  spec.license = "GPL-2.0-or-later"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = `git ls-files -z`.split("\0") |
    ["lib/alexandria/default_preferences.rb"]
  spec.bindir = "exe"

  spec.executables = ["alexandria"]

  spec.require_paths = ["lib"]
  spec.rdoc_options = ["--main", "README.md"]

  spec.add_dependency "alexandria-zoom", ["~> 0.6.0"]
  spec.add_dependency "csv", "~> 3.2"
  spec.add_dependency "gettext", ["~> 3.1"]
  spec.add_dependency "gstreamer", "~> 4.2.0"
  spec.add_dependency "gtk3", "~> 4.2.0"
  spec.add_dependency "htmlentities", ["~> 4.3"]
  spec.add_dependency "image_size", ["~> 3.0"]
  spec.add_dependency "marc", "~> 1.3"
  spec.add_dependency "nokogiri", ["~> 1.11"]
  spec.add_dependency "observer", "~> 0.1.2"

  spec.add_development_dependency "gnome_app_driver", "~> 0.3.2"
  spec.add_development_dependency "rake", ["~> 13.0"]
  spec.add_development_dependency "rspec", ["~> 3.0"]
  spec.add_development_dependency "rubocop", "~> 1.79"
  spec.add_development_dependency "rubocop-i18n", "~> 3.2"
  spec.add_development_dependency "rubocop-performance", "~> 1.25"
  spec.add_development_dependency "rubocop-rake", "~> 0.7.1"
  spec.add_development_dependency "rubocop-rspec", "~> 3.6"
  spec.add_development_dependency "simplecov", "~> 0.22.0"
  spec.add_development_dependency "webmock", "~> 3.9"
end
