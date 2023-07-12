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

require "fileutils"
require "pathname"
require "rake/tasklib"

class OmfGenerateTask < Rake::TaskLib
  def initialize(projectname)
    @projectname = projectname
    @generated_files = []
    yield self if block_given?
    make_task
  end

  def make_task
    desc "Generate Open Metadata Framework files"
    task omf: @generated_files

    @generated_files.each { |gen| CLOBBER << gen } if CLOBBER
  end

  def locale_for(omf_file)
    omf_file =~ /.*-(.+)\.omf/
    Regexp.last_match[1]
  end

  def in_files
    FileList["#{@source_dir}/*.omf.in"]
  end

  def omf_files
    in_files.map { |f| f.sub(/.omf.in/, ".omf") }
  end

  attr_writer :gnome_helpfiles_dir

  def generate_omf(src_dir, file_glob)
    @source_dir = src_dir
    @source_files_glob = file_glob

    rule ".omf" => [".omf.in"] do |t|
      path = File.join(@gnome_helpfiles_dir, @projectname,
                       locale_for(t.name), "#{@projectname}.xml")
      data = File.read(t.source)
      data.sub!("PATH_TO_DOC_FILE", path)
      puts "Generating #{t.name}..."
      File.open(t.name, "w") { |io| io.puts data }
    end
    omf_files.each { |o| @generated_files << o }
  end
end
