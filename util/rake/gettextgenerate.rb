# frozen_string_literal: true

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
    yield self if block_given?
    make_task
  end

  def make_task
    desc 'Generate gettext localization files'
    task gettext: @generated_files

    @generated_files.each { |gen| CLOBBER << gen } if CLOBBER
  end

  def generate_po_files(po_dir, file_glob, dest_dir)
    @po_dir = po_dir
    @po_files_glob = file_glob
    @mo_dir = dest_dir
    @mo_files_regex = /.*\/(.+)\/LC_MESSAGES\/.+\.mo/

    # create MO files
    rule(/\.mo$/ => [->(dest) { source_file(dest) }]) do |t|
      dest_dir = File.dirname(t.name)
      FileUtils.makedirs(dest_dir) unless FileTest.exists?(dest_dir)
      puts "Generating #{t.name}"
      system("msgfmt #{t.source} -o #{t.name}")
      raise "msgfmt failed for #{t.source}" if $CHILD_STATUS.nonzero?
    end
    mo_files.each { |mo| @generated_files << mo }
  end

  def po_files
    FileList[@po_files_glob]
  end

  def generate_desktop(infile, outfile)
    @generated_files << outfile
    file outfile => [infile, *po_files] do |_f|
      begin
        `intltool-merge --version`
      rescue Errno::ENOENT
        raise 'Need to install intltool'
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
    po_file_for(Regexp.last_match[1])
  end
end
