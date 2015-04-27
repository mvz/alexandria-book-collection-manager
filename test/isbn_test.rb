#!/usr/bin/ruby
# Copyright (C) 2004-2006 Dafydd Harries
# Copyright (C) 2011, 2014 Matijs van Zuijlen
#
# This file is part of Alexandria, a GNOME book collection manager.
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

require File.expand_path('test_helper.rb', File.dirname(__FILE__))

require 'alexandria/import_library'

class TestISBN < MiniTest::Test
  def __test_fake_import_isbns
    libraries = Alexandria::Libraries.instance
    library = Alexandria::Library.new('Test Library')
    libraries.add_library(library)
    [library, libraries]
  end

  def test_valid_ISBN
    for x in ['014143984X', '0-345-43192-8']
      assert Alexandria::Library.valid_isbn?(x)
    end
  end

  def test_valid_EAN
    assert Alexandria::Library.valid_ean?('9780345431929')

    # Regression test: this EAN has a checksum of 10, which should be
    # treated like a checksum of 0.
    assert Alexandria::Library.valid_ean?('9784047041790')
  end

  def test_canonical_ISBN
    assert_equal '014143984X',
    Alexandria::Library.canonicalise_isbn('014143984X')
    assert_equal '0345431928',
    Alexandria::Library.canonicalise_isbn('0-345-43192-8')
    assert_equal '3522105907',
    Alexandria::Library.canonicalise_isbn('3522105907')
    # EAN number
    assert_equal '0345431928',
    Alexandria::Library.canonicalise_isbn('9780345431929')
  end

  # Doesn't work quite yet.
  #     def test_ISBN_import_bad_number
  #             on_iterate_cb = proc { }
  #             on_error_cb = proc { }
  #             library, libraries = __test_fake_import_isbns
  #             test_file = "data/isbns.txt"
  #             library.import_as_isbn_list("Test Library", test_file, on_iterate_cb, on_error_cb)
  #     end
end
