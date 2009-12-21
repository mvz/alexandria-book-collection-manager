# -*- ruby -*-
#--
# Copyright (C) 2009 Cathal Mc Ginley
#
# This file is part of the Alexandria build system.
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
  def initialize(taskname, dirname=nil, install_to_rubylibdir=false)
    @taskname = taskname
    @install_to_rubylibdir = install_to_rubylibdir
    calculate_ruby_dir
    @stage_dir = dirname # || @prefix
    @file_groups = []
    @dirs_to_remove_globs = []
    if block_given?
      yield self
    end
    make_tasks
  end

  protected

  # Creates the install and uninstall tasks based on the contents
  # of the @file_groups list
  def make_tasks
    tasknames = {}
    tasknames[:install] = "install_#{@taskname}".intern
    tasknames[:uninstall] = "uninstall_#{@taskname}".intern
    tasknames[:uninstall_files] = "uninstall_#{@taskname}_files".intern
    tasknames[:uninstall_dirs] = "uninstall_#{@taskname}_dirs".intern

    # INSTALL TASK

    description = "Install package files"
    if @stage_dir
      description += " to staging directory"
    end
    desc description
    task tasknames[:install] do
      @file_groups.each {|g| g.install(@stage_dir) }
    end    

    # UNINSTALL TASKS

    task tasknames[:uninstall_files] do
      @file_groups.each {|g| g.uninstall(@stage_dir) }
    end    

    task tasknames[:uninstall_dirs] => tasknames[:uninstall_files] do
      all_dirs = Set.new
      @file_groups.each {|g| g.get_installation_dirs(@stage_dir, all_dirs) }
      

      to_delete = Set.new
      @dirs_to_remove_globs.each do |glob|
        regex = glob2regex(glob)
        all_dirs.each do |dir|
          unless dir =~ /\/$/
            dir += '/'
          end
          if regex =~ dir            
            to_delete << $1
          end
        end
      end
      to_delete.each do |dirname|
        dir = dirname
        if @stage_dir
          dir = File.join(@stage_dir, dirname)
        end
        delete_empty(dir)
      end
    end

    uninstall_description = "Uninstall package files"
    if @stage_dir
      uninstall_description += " from staging directory"
    end   
    desc uninstall_description
    task tasknames[:uninstall] => [tasknames[:uninstall_files], 
                                   tasknames[:uninstall_dirs]]

  end
  


  public

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
        group = FileGroup.new(icon_dir, f, icon_dest_dir)
        group.description = "icons"
        @file_groups << group
      end
    end
  end

  # Specify which directories should be deleted by the uninstall task
  # if they are empty (or only contain more empty directories).
  def uninstall_empty_dirs(dir_globs)
    @dirs_to_remove_globs = dir_globs
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
    elsif ruby_libdir.index(ruby_prefix) == 0
      libpart = ruby_libdir[ruby_prefix.size .. -1]
      @rubylib = File.join(@prefix, libpart)
    else
      @rubylib = ruby_libdir
    end
  end

  def glob2regex(pathglob)
    if pathglob =~ /\*\*$/
      pathglob += "/"
    end
    real_parts = pathglob.split("**/")
    real_parts.each do |part|
      part.gsub!(".", "\\.")
      part.gsub!("*", "[^\\/]*")
      part.gsub!("?", "[^\\/]")
    end
    pattern = real_parts.join("([^\/]+\/)*")
    return /(#{pattern})/
  end

  # For each of the directories named in the list +dirs+, delete the
  # tree if is empty except for further empty directories.
  def delete_empty(dirs)
    dirs.each do |d|
      p = Pathname.new(d)
      if p.exist?
        delete_if_empty(p.realpath)
      end
    end
  end

  
  # Delete the directory at the given Pathname +p+ if all its children
  # can be similarly deleted, and if it is then empty.
  def delete_if_empty(p)
    unless p.directory?
      return false
    end
    p.children.each do |c|
      delete_if_empty(c)
    end
    if p.children.empty?
      p.delete # TODO optional verbose output here
      true
    else
      false
    end
  end

  class FileGroup
    attr_reader :mode
    attr_accessor :description
    def initialize(src_dir, file_glob, dest_dir, mode=0644)
      @src_dir = src_dir
      @file_glob = file_glob
      @dest_dir = dest_dir
      @mode = mode
      @description = "files"
    end
    def to_s
      "FileGroup[#{@src_dir}] => #{@dest_dir}"
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
      puts "Installing #{@description} to #{base_dir}#{@dest_dir}"
      files.each do |f|
        dest = self.dest_dir(f, base_dir)
        FileUtils.mkdir_p(dest) unless test(?d, dest)
        if test(?f, f)
          FileUtils.install(f, dest, :mode => self.mode)
        end
      end
    end

    def uninstall(base_dir)
      files.each do |f|
        dest = self.dest_dir(f, base_dir)
        filename = File.basename(f)
        file = File.join(dest, filename)
        if test(?f, file)
          FileUtils::Verbose.rm_f(file) #, :noop => true)
        end
      end
    end

    def get_installation_dirs(base_dir, all_dirs_set)
      files.each do |f|
        dest = self.dest_dir(f, base_dir)
        filename = File.basename(f)
        file = File.join(dest, filename)
        all_dirs_set << File.dirname(file)
      end
    end
      

  end # class FileGroup

end # class FileInstallTask
