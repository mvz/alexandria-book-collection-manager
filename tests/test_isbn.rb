#!/usr/bin/ruby
# Copyright (C) 2004-2005 Dafydd Harries

require 'test/unit'
require 'gettext'
require 'alexandria'

class TestISBN < Test::Unit::TestCase
    def test_valid_ISBN
        for x in ["014143984X", "0-345-43192-8"]
            assert Alexandria::Library.valid_isbn?(x)
        end
    end

    def test_valid_EAN
        assert Alexandria::Library.valid_ean?("9780345431929")

        # Regression test: this EAN has a checksum of 10, which should be
        # treated like a checksum of 0.
        assert Alexandria::Library.valid_ean?("9784047041790")
    end

    def test_canonical_ISBN
        assert_equal "014143984X",
            Alexandria::Library.canonicalise_isbn("014143984X")
        assert_equal "0345431928",
            Alexandria::Library.canonicalise_isbn("0-345-43192-8")
        assert_equal "3522105907",
            Alexandria::Library.canonicalise_isbn("3522105907")
        # EAN number
        assert_equal "0345431928",
            Alexandria::Library.canonicalise_isbn("9780345431929")
    end
end
