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
require 'rake/tasklib'

class GettextGenerateTask < Rake::TaskLib

  def initialize(projectname)
    @projectname = projectname
    @generated_files = []
    if block_given?
      yield self
    end
    make_task
  end

  def make_task
    desc "Generate gettext localization files"
    task :gettext => @generated_files
      
    if CLOBBER
      @generated_files.each {|gen| CLOBBER << gen }
    end
  end

  def generate_po_files(po_dir, file_glob, dest_dir)
    @po_dir = po_dir
    @po_files_glob = file_glob
    @mo_dir = dest_dir
    @mo_files_regex = /.*\/(.+)\/LC_MESSAGES\/.+\.mo/

    # create MO files
    rule( /\.mo$/ => [ lambda { |dest| source_file(dest) }]) do |t|
      dest_dir = File.dirname(t.name)
      FileUtils.makedirs(dest_dir) unless FileTest.exists?(dest_dir)
      puts "Generating #{t.name}"
      system("msgfmt #{t.source} -o #{t.name}")
      raise "msgfmt failed for #{t.source}" if $? != 0
    end
    mo_files.each {|mo| @generated_files << mo }
  end

  def po_files
    FileList[@po_files_glob]
  end

  def generate_desktop(infile, outfile)
    @generated_files << outfile
    file outfile => [infile, *po_files] do |f|
      unless `intltool-merge --version`
        raise Exception, "Need to install intltool"
      end
      system("intltool-merge -d #{@po_dir} #{infile} #{outfile}")
    end
  end


  def locales
    po_files.map { |po| File.basename(po).split('.')[0] }
  end
  
  def mo_files
    locales.map { |loc| mo_file_for(loc) }
  end

  def po_file_for(locale)
    "#{@po_dir}/#{locale}.po"
  end

  def mo_file_for(locale)
    "#{@mo_dir}/#{locale}/LC_MESSAGES/#{@projectname}.mo"
  end



  def source_file(dest_file)
    dest_file =~ @mo_files_regex
    po_file_for($1)
  end
end

#   class GettextConfig < BuildConfig
#     attr_accessor :po_dir, :po_files_glob
#     attr_accessor :mo_dir, :mo_files_regex
#     def initialize(build)
#       super(build)
#       @po_dir = 'po'
#       @po_files_glob = "#{@po_dir}/*.po"
#       @mo_dir = 'data/locale'
#       @mo_files_regex = /.*\/(.+)\/LC_MESSAGES\/.+\.mo/
#     end
#     def po_files
#       FileList[po_files_glob]
#     end
#     def po_file_for(locale)
#       "#{po_dir}/#{locale}.po"
#     end
#     def locales
#       po_files.map { |po| File.basename(po).split('.')[0] }
#     end
#     def mo_files
#       locales.map { |loc| mo_file_for(loc) }
#     end
#     def mo_file_for(locale)
#       "#{mo_dir}/#{locale}/LC_MESSAGES/#{build.name}.mo"
#     end
#     def source_file(dest_file)
#       dest_file =~ mo_files_regex
#       po_file_for($1)
#     end
#   end

#   def define_gettext_tasks
#     # extract translations from PO files into other files
#     file files.desktop => ["#{files.desktop}.in",
#       *@gettext.po_files] do |f|
#       raise "Need to install intltool" unless system("intltool-merge -d #{@gettext.po_dir} #{f.name}.in #{f.name}")
#       end

#     # create MO files
#     rule( /\.mo$/ => [ lambda { |dest| @gettext.source_file(dest) }]) do |t|
#       dest_dir = File.dirname(t.name)
#       FileUtils.makedirs(dest_dir) unless FileTest.exists?(dest_dir)
#       puts "Generating #{t.name}"
#       system("msgfmt #{t.source} -o #{t.name}")
#       raise "msgfmt failed for #{t.source}" if $? != 0
#     end

#     desc "Generate gettext localization files"
#     task :gettext => [files.desktop, *@gettext.mo_files]

#     task :clobber_gettext do
#       FileUtils.rm_f(files.desktop)
#       FileUtils.rm_rf(@gettext.mo_dir)
#     end
#     task :clobber => [:clobber_gettext]
#   end
