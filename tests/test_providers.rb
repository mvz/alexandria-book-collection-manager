#!/usr/bin/env ruby
# Copyright (C) 2005 Laurent Sansonetti 

require 'test/unit'
require 'gettext'
require 'alexandria'

$KCODE = "U"

class TestProviders < Test::Unit::TestCase
    def __test_provider(provider, isbn)
        search_type = Alexandria::BookProviders::SEARCH_BY_ISBN
        results = nil
        assert_nothing_raised do    
            results = provider.instance.search(isbn, search_type)
        end
        assert_kind_of(Array, results)
        assert(!results.empty?)
        assert(results.length <= 2)
        if results.length == 2
            assert_kind_of(String, results.last)
        end
        assert_kind_of(Alexandria::Book, results.first)
        assert(results.first.isbn == isbn)	
    end
    
    def test_amazon
        __test_provider(Alexandria::BookProviders::AmazonProvider,
                        '0385504209')
    end

    def test_bn
        __test_provider(Alexandria::BookProviders::BNProvider,
                        '0961328916')   # see #1433  
    end

    def test_mcu
        __test_provider(Alexandria::BookProviders::MCUProvider,
                        '8420636665') 
    end

    def test_proxis
        __test_provider(Alexandria::BookProviders::ProxisProvider,
                        '9026965745')
	__test_provider(Alexandria::BookProviders::ProxisProvider,
			'0586071407')
    end

    def test_amadeus
        __test_provider(Alexandria::BookProviders::AmadeusProvider,
                        '3453864662') 
    end

    def test_ibs_it
        __test_provider(Alexandria::BookProviders::IBS_itProvider,
                        '8851520666') 
    end
end
