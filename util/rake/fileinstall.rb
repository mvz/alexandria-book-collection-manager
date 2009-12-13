# -*- ruby -*-
#--
# Copyright (C) 2009 Cathal Mc Ginley
#
# This file is part of the Palatina build system.
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

require 'fileutils'
require 'pathname'
require 'set'
require 'rake/tasklib'

# A file installer task, capable of installing into the system
# directories, or doing a staged install to a given directory
# (preparatory to bundling the installed files in a binary package
# such as deb or rpm).
class FileInstallTask < Rake::TaskLib

  # The calculated location of the preferred ruby lib installation dir.
  attr_reader :rubylib

  # Creates an installer task with the given +taskname+. If a
  # +dirname+ is given, the task will perform a staged installation to
  # that directory with a correct sub-tree e.g. 'tmp/usr/bin',
  # 'tmp/usr/share/doc/packagename'.
  #
  # This constructor is called with a block, which is passed the
  # installer task. You should call +install+ or +install_exe+ on that
  # installer as follows:
  #
  #     FileInstallTask.new(:install) do |i|
  #       i.install('lib', 'lib/**/*.rb', i.rubylib)
  #       i.install_exe('bin', 'bin/*', '/usr/bin')
  #     end
  #
  # If you set +install_to_rubylibdir+ true, or specify the
  # +RUBYLIBDIR+ environment variable, you can ensure the files are
  # installed in the correct place for staged installation, e.g. on
  # Debian, set +dirname+ to 'debian/packagename' and
  # +install_to_rubylibdir+ to true so that files are stage-installed
  # to 'debian/packagename/usr/lib/ruby/1.8'
  def initialize(taskname=nil, dirname=nil, install_to_rubylibdir=false)
    @taskname = taskname
    @install_to_rubylibdir = install_to_rubylibdir
    calculate_ruby_dir
    @stage_dir = dirname # || @prefix
    @file_groups = []
    if block_given?
      yield self
    end
    if taskname
      # taskname will be nil for newly cloned tasked (c.f. #similar)
      # so we don't make the new task yet...
      make_tasks
    end

  end

  protected

  # Creates the install and uninstall tasks based on the contents
  # of the @file_groups list
  def make_tasks
    description = "Install package files"
    if @stage_dir
      description += " to staging directory"
    end
    desc description
    task @taskname do
      @file_groups.each {|g| g.install(@stage_dir) }
    end    

    uninstall_description = "Uninstall package files"
    if @stage_dir
      description += " from staging directory"
    end
    
    #desc uninstall_description
    task "un_#{@taskname}".intern do
      @dirs = Set.new
      @file_groups.each {|g| g.uninstall(@stage_dir, @dirs) }
    end    
  end

  attr_accessor :file_groups, :stage_dir, :taskname

  public


  # Makes a copy of this install task, with the same file groups
  # already set, but to which more file groups can be added without
  # interference.
  def similar(taskname, dirname=nil, install_to_rubylibdir=false)
    newtask = self.dup
    newtask.taskname = taskname
    newtask.stage_dir = dirname
    if block_given?
      yield newtask 
    end   
    newtask.make_tasks
    newtask
  end
    
  
  # Include the files specified in the +file_glob+ to be installed in
  # +dest_dir+, but noting that the prefix +src_dir+ is to be
  # disregarded in the installation.
  #
  # This means that
  #     i.install('data', 'data/gnome/**', '/usr/share')
  # would install files in the 'data/gnome/help' directory to
  # '/usr/share/gnome/help'
  def install(src_dir, file_glob, dest_dir)
    @file_groups << FileGroup.new(src_dir, file_glob, dest_dir)
  end

  # Install files the same way as +install+, but setting the mode of
  # the installed file to be executable.
  def install_exe(src_dir, file_glob, dest_dir)
    @file_groups << FileGroup.new(src_dir, file_glob, dest_dir, 0755)
  end


  # Install icon files. This method splits up the source file name and
  # determines where they should be put in the destination hierarchy.
  def install_icons(file_globs, dest_dir, theme='hicolor', icon_type='apps')
    file_globs.each do |fg|
      files = FileList.new(fg)
      files.each do |f|
        icon_file = Pathname.new(f)
        icon_filename = icon_file.basename
        icon_dir = icon_file.dirname
        icon_size = Pathname.new(icon_dir).basename
        icon_dest_dir = "#{dest_dir}/#{theme}/#{icon_size}/#{icon_type}"
        @file_groups << FileGroup.new(icon_dir, f, icon_dest_dir)
      end
    end
  end

  # Specify which directories should be deleted by the uninstall task
  # if they are empty (or only contain more empty directories).
  def uninstall_empty_dirs(dir_globs)
    task "un_#{@taskname}_empty_dirs".intern => "un_#{@taskname}".intern do
      puts "TODO implement uninstall_empty_dirs"
      #FileList.new(dir_globs).each do |f|
      #  puts f
      #end
    end
  end

  private

  def calculate_ruby_dir
    ruby_prefix = Config::CONFIG['prefix']

    if @install_to_rubylibdir
      ruby_libdir = Config::CONFIG['rubylibdir']
    else
      ruby_libdir = Config::CONFIG['sitelibdir']
    end
    if ENV.has_key?('RUBYLIBDIR')
      ruby_libdir = ENV['RUBYLIBDIR']
    end 

    @prefix = ENV['PREFIX'] || ruby_prefix
    if @prefix == ruby_prefix
      @rubylib = ruby_libdir
    else
      libpart = ruby_libdir[ruby_prefix.size .. -1]
      @rubylib = File.join(@prefix, libpart)
    end
  end


  class FileGroup
    attr_reader :mode
    def initialize(src_dir, file_glob, dest_dir, mode=0644)
      @src_dir = src_dir
      @file_glob = file_glob
      @dest_dir = dest_dir
      @mode = mode
    end
    def to_s
      "FileGroup[#{@src_dir}]"
    end
    def dest_dir(file, staging_dir=nil)
      source_basedir = Pathname.new(@src_dir)
      source_file = Pathname.new(file)

      if staging_dir
        stage_dest = File.join(staging_dir, @dest_dir)
        dest_basedir = Pathname.new(stage_dest)
      else
        dest_basedir = Pathname.new(@dest_dir)
      end
      if source_file.file?
        source_path = source_file.dirname.relative_path_from(source_basedir)
      end
      dest = source_path ? dest_basedir + source_path : dest_basedir
      return dest.to_s
    end

    def files
      FileList.new(@file_glob)
    end

    def install(base_dir)
      files.each do |f|
        dest = self.dest_dir(f, base_dir)
        FileUtils.mkdir_p(dest) unless test(?d, dest)
        if test(?f, f)
          FileUtils::Verbose.install(f, dest, :mode => self.mode)
        end
      end
    end

    def uninstall(base_dir, dirs)
      files.each do |f|
        dest = self.dest_dir(f, base_dir)
        filename = File.basename(f)
        file = File.join(dest, filename)
        if test(?f, file)
          FileUtils::Verbose.rm_f(file) #, :noop => true)
          dirs << File.dirname(file)
        end
      end
    end

  end # class FileGroup

end # class FileInstallTask
