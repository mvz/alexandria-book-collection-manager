require 'fileutils'
include FileUtils
require 'rake/clean'
require 'pallet'

Pallet.new('alexandria', Pallet::VERSION) do |p|
  p.author = 'Joseph Method'
  p.email  = 'tristil@gmail.com'
  p.summary = 'A book library manager for Gnome'
  p.version = '0.6.2'
  p.description = <<-DESC.margin
    |Alexandria is a book library manager for gnome, written in Ruby.
    DESC
  p.packages << Pallet::Deb.new(p => :doc) do |deb|
    deb.architecture = 'all'
    deb.changelog = 'ChangeLog' 
    deb.depends     = %w{ruby-gnome2(>=0.15) libwww-mechanize-ruby libimage-size-ruby1.8}
    deb.recommends = %w{fakeroot}
    deb.prerequisites = [:presetup]
    deb.section     = 'misc'
    deb.copyright = 'COPYING'
    deb.files       = [ Installer.new('lib',   '/usr/lib/ruby/1.8'),
                        Installer.new('data', '/usr/share/alexandria'),
                        Installer.new('bin',   '/usr/bin') { FileList["alexandria"]},
                      ]
    #deb.docs        = [ Installer.new('doc', 'html'), ]
  end
end

task :presetup do
  basename = "alexandria"
  config = Config::CONFIG
  #podir = srcdir_root + "/po/"

  system("intltool-merge -d po alexandria.desktop.in alexandria.desktop")
  # Create MO files.

  Dir.glob("po/*.po") do |file|
    lang = /po\/(.*)\.po/.match(file).to_a[1]
    mo_path_bits = ['data', 'locale', lang, 'LC_MESSAGES']
    mo_path = File.join(mo_path_bits)
    (0 ... mo_path_bits.length).each do |i|
      path = File.join(mo_path_bits[0 .. i])
      puts path
      Dir.mkdir(path) unless FileTest.exists?(path)
    end
  
    system("msgfmt po/#{lang}.po -o #{mo_path}/#{basename}.mo")
    raise "msgfmt failed on po/#{lang}.po" if $? != 0
  end

end

task :postinstall do 
  exit 0 if ENV['GCONF_DISABLE_MAKEFILE_SCHEMA_INSTALL']

  unless system("which gconftool-2")
    $stderr.puts "gconftool-2 cannot be found, is GConf2 correctly installed?"
    exit 1
  end

  ENV['GCONF_CONFIG_SOURCE'] = `gconftool-2 --get-default-source`.chomp
  Dir["schemas/*.schemas"].each do |schema|
    system("gconftool-2 --makefile-install-rule '#{schema}'") 
  end
end
