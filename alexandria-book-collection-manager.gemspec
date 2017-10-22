require_relative 'lib/alexandria/version'

Gem::Specification.new do |s|
  s.name = 'alexandria-book-collection-manager'
  s.version = Alexandria::VERSION

  s.summary = 'GNOME application for managing collections of books'
  s.required_ruby_version = '>= 1.9.3'

  s.authors = [
    'Alexander McCormmach',
    'Aymeric Nys',
    'Cathal Mc Ginley',
    'Claudio Belotti',
    'Constantine Evans',
    'Dafydd Harries',
    'Javier Fernandez-Sanguino Pena',
    'Joseph Method',
    'Kevin Schultz',
    'Laurent Sansonetti',
    'Marco Costantini',
    'Mathieu Leduc-Hamel',
    'Matijs van Zuijlen',
    'Owain Evans',
    'Pascal Terjan',
    'Rene Samselnig',
    'Robby Stephenson',
    'Sun Ning',
    'Takayuki Kusano',
    'Timothy Malone',
    'Zachary P. Landau'
  ]
  s.email = ['matijs@matijs.net']
  s.homepage = 'http://www.github.com/mvz/alexandria-book-collection-manager'

  s.license = 'GPL-2'

  s.files = `git ls-files -z`.split("\0") |
    ['lib/alexandria/default_preferences.rb']

  s.executables = ['alexandria']

  s.rdoc_options = ['--main', 'README.md']

  s.add_runtime_dependency('gettext', ['~> 3.1'])
  s.add_runtime_dependency('hpricot', ['~> 0.8.5'])
  s.add_runtime_dependency('htmlentities', ['~> 4.3'])
  s.add_runtime_dependency('gtk3', ['3.1.9'])
  s.add_runtime_dependency('gstreamer', ['3.1.9'])
  s.add_runtime_dependency('image_size', ['~> 1.5.0'])
  s.add_runtime_dependency('marc', ['~> 1.0.0'])
  s.add_runtime_dependency('zoom', ['~> 0.5.0'])

  s.add_development_dependency('minitest', ['~> 5.0'])
  s.add_development_dependency('rake', ['~> 12.0'])
  s.add_development_dependency('rspec', ['~> 3.0'])

  s.require_paths = ['lib']
end
