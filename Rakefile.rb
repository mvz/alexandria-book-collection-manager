require 'fileutils'
include FileUtils
require 'rake/clean'

PREFIX = "/usr/local/"
SITE_RUBY = PREFIX + 'lib/site_ruby/1.8'
LIBS = FileList['lib/*'] 
DATA = FileList['data/*']
PO = FileList['po/*']
BIN = FileList['bin/*']
SCHEMA = FileList['schemas/*']

# CLEAN.include? 

task :default => [:test]

desc "Install Alexandria"
task :install => [:presetup, :move_files, :postinstall] do
end

task :move_files do 
  #Install libs
  LIBS.each do |lib|
    cp_r lib, SITE_RUBY
  end
  #Install data 
  begin
    mkdir PREFIX + 'share/alexandria'
  rescue Errno::EEXIST
  end
  DATA.each do |datum|
    cp_r datum, PREFIX + 'share/alexandria' 
  end
  #Install bin
    cp_r 'bin/alexandria', PREFIX + 'bin'
    chmod 0755, PREFIX + 'bin/alexandria'
  #Install docs
  #Not done yet
end

desc "Install Alexandria and clobber old system files"
task :install_clean => [:systemclean, :presetup, :move_files, :postinstall] do
  puts "Installing Alexandria..."
end

task :test do
  puts "Testing Alexandria..."
  cd 'tests'
  require 'test'
end

task :systemclean do
  puts "Killing old files..."
  # Kill lib files
  rm_rf SITE_RUBY + 'alexandria' 
  rm_rf SITE_RUBY + 'alexandria.rb'
  # Kill bin files
  rm PREFIX + 'bin/alexandria'
  # Kill data files
  rm_rf PREFIX + 'share/alexandria'
  # Kill schema files
  rm_rf PREFIX + 'share/doc/alexandria'
end

task :print do
  [LIBS, DATA, PO, BIN, SCHEMA].each {|i| puts i }
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
