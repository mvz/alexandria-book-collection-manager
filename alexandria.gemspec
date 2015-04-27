# -*- encoding: utf-8 -*-
require_relative 'lib/alexandria/version'

Gem::Specification.new do |s|
  s.name = 'alexandria'
  s.version = Alexandria::VERSION

  s.summary = 'GNOME application for managing collections of books'
  s.required_ruby_version = '>= 1.9.3'

  s.authors = ['Matijs van Zuijlen']
  s.email = ['matijs@matijs.net']
  s.homepage = 'http://www.github.com/mvz/alexandria-book-collection-manager'

  s.license = 'GPL-2'

  s.files = `git ls-files -z`.split("\0") |
    ['lib/alexandria/default_preferences.rb']

  s.executables = s.files.grep(%r{^bin/}).map { |path| File.basename(path) }

  s.rdoc_options = ['--main', 'README.md']

  s.add_runtime_dependency('gettext', ['~> 3.1'])
  s.add_runtime_dependency('hpricot', ['~> 0.8.5'])
  s.add_runtime_dependency('htmlentities', ['~> 4.3'])
  s.add_runtime_dependency('gtk2', ['~> 2.2'])
  s.add_runtime_dependency('gstreamer', ['~> 2.2'])

  s.add_development_dependency('minitest', ['~> 5.0'])
  s.add_development_dependency('rake', ['~> 10.0'])
  s.add_development_dependency('rspec', ['~> 3.0'])

  s.require_paths = ['lib']
end
