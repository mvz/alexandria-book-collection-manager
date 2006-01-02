# Copyright (C) 2005-2006 Dafydd Harries

require 'fileutils'

clean_files = [
    'alexandria.desktop',
    'alexandria.desktop.in.h',
    'bin/alexandria',
    'lib/alexandria/config.rb',
    'lib/alexandria/version.rb',
    'data/omf/alexandria-C.omf'
    ]

for file in clean_files
    puts "rm -f #{file}"
    FileUtils.rm_f(file)
end

