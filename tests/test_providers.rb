#!/usr/bin/env ruby
# Copyright (C) 2005-2006 Laurent Sansonetti 

require 'test/unit'
require 'gettext'
require 'alexandria'

$KCODE = "U"

class TestProviders < Test::Unit::TestCase
    def __test_provider(provider, isbn)
        search_type = Alexandria::BookProviders::SEARCH_BY_ISBN
        results = nil
        assert_nothing_raised("Something wrong here.") do    
            results = provider.instance.search(isbn, search_type)
        end
        #puts results.inspect
        assert_kind_of(Array, results, "Results are not an array")
        assert(!results.empty?, "Results are empty")
        assert(results.length <= 2, "Results are greater than 2")
        if results.length == 2
            assert_kind_of(String, results.last, "Result is not a String")
        end
        assert_kind_of(Alexandria::Book, results.first, "Result is not a Book")
        assert(results.first.isbn == isbn, "Result's isbn #{results.first.isbn} is not the same as requested isbn #{isbn}")
        
    end
    
    def test_amazon
        __test_provider(Alexandria::BookProviders::AmazonProvider,
                        '0385504209')
    end

#     def test_bn
#         __test_provider(Alexandria::BookProviders::BNProvider,
#                         '0961328916')   # see #1433  
#     end

#     def test_mcu
#         __test_provider(Alexandria::BookProviders::MCUProvider,
#                         '8420636665') 
#     end

    def test_proxis
        __test_provider(Alexandria::BookProviders::ProxisProvider,
                        '9026965745')
		__test_provider(Alexandria::BookProviders::ProxisProvider,
			'0586071407')
    end

    def test_amadeus
        __test_provider(Alexandria::BookProviders::AmadeusProvider,
                        '3896673300') 
    end

    def test_ibs_it_1 # this tests a book without image but with author
        __test_provider(Alexandria::BookProviders::IBS_itProvider,
                        '9788886973816') 
    end
    
    def test_ibs_it_2 # this tests a book with image but without author
        __test_provider(Alexandria::BookProviders::IBS_itProvider,
                        '8807710145') 
    end
    
    def test_adlibris
        __test_provider(Alexandria::BookProviders::AdlibrisProvider,
                        '9100109339') 
    end
     
    def test_siciliano
        __test_provider(Alexandria::BookProviders::SicilianoProvider,
                        '8599170384') 
    end

    def test_dea
        __test_provider(Alexandria::BookProviders::DeaStore_itProvider,
                        '881701298X') 
    end

    def test_bol
        __test_provider(Alexandria::BookProviders::BOL_itProvider,
                        '881701298X') 
    end

end
