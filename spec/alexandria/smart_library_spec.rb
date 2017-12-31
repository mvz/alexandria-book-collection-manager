# frozen_string_literal: true

# Copyright (C) 2007 Joseph Method
#
# Alexandria is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# Alexandria is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with Alexandria; see the file COPYING.  If not,
# write to the Free Software Foundation, Inc., 51 Franklin Street,
# Fifth Floor, Boston, MA 02110-1301 USA.

require File.dirname(__FILE__) + '/../spec_helper'

describe Alexandria::SmartLibrary do
  it 'can be instantiated simply' do
    lib = described_class.new('Hello', [], :all)
    expect(lib.name).to eq 'Hello'
  end

  it 'normalizes the encoding for name' do
    bad_name = 'Prêts'.force_encoding('ascii')
    lib = described_class.new(bad_name, [], :all)
    expect(lib.name.encoding.name).to eq 'UTF-8'
    expect(bad_name.encoding.name).to eq 'US-ASCII'
  end
end
