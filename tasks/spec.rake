# frozen_string_literal: true

# -*- ruby -*-
#--
# Copyright (C) 2011 Matijs van Zuijlen
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

require 'rspec/core/rake_task'

namespace 'spec' do
  RSpec::Core::RakeTask.new('unit') do |t|
    t.pattern = 'spec/alexandria/**/*_spec.rb'
    t.ruby_opts = ['-rbundler/setup -rsimplecov -Ilib -w']
  end

  RSpec::Core::RakeTask.new('end_to_end') do |t|
    t.pattern = 'spec/end_to_end/**/*_spec.rb'
    t.ruby_opts = ['-rbundler/setup -rsimplecov -Ilib -w']
  end

  desc 'Runs all unit and end-to-end specs'
  task 'all' => ['spec:unit', 'spec:end_to_end']
end

task default: 'spec:all'
