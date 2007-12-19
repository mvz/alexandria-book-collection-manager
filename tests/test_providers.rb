#!/usr/bin/env ruby
# Copyright (C) 2005-2006 Laurent Sansonetti

require 'test/unit'
require 'gettext'
require 'alexandria'

$KCODE = "U"

class TestProviders < Test::Unit::TestCase
  def __test_provider(provider, query, search_type = Alexandria::BookProviders::SEARCH_BY_ISBN)
    results = nil
    assert_nothing_raised("Something wrong here.") do
      results = provider.instance.search(query, search_type)
    end
    puts results.inspect if $DEBUG
    assert_kind_of(Array, results, "Results are not an array")
    assert(!results.empty?, "Results are empty")
    if search_type == Alexandria::BookProviders::SEARCH_BY_ISBN
      assert(results.length <= 2, "Results are greater than 2")
      if results.length == 2
        assert_kind_of(String, results.last, "Result is not a String")
      end
      assert(results.first.isbn == query, "Result's isbn #{results.first.isbn} is not the same as requested isbn #{query}")
      assert_kind_of(Alexandria::Book, results.first, "Result is not a Book")
      results.first
    else
      assert_kind_of(Alexandria::Book, results.first.first, "Result item is not a Book")
    end
  end


  #  providers depending on optional libraries

  def test_amazon_isbn
    __test_provider(Alexandria::BookProviders::AmazonProvider,
                    '9780385504201')
  end

  def test_amazon_title
    __test_provider(Alexandria::BookProviders::AmazonProvider,
                    'A Confederacy of Dunces', Alexandria::BookProviders::SEARCH_BY_TITLE)
  end

  def test_amazon_author
    __test_provider(Alexandria::BookProviders::AmazonProvider,
                    'John Kennedy Toole', Alexandria::BookProviders::SEARCH_BY_AUTHORS)
  end

  def test_amazon_keyword
    __test_provider(Alexandria::BookProviders::AmazonProvider,
                    'Confederacy Dunces', Alexandria::BookProviders::SEARCH_BY_KEYWORD)
  end

  def test_dea
    __test_provider(Alexandria::BookProviders::DeaStore_itProvider,
                    '9788817012980')
    __test_provider(Alexandria::BookProviders::DeaStore_itProvider,
                    '9788806134747')
  end

  # Right? Don't test if dependency isn't present.

  def test_LOC
    begin
      require 'zoom'
    rescue LoadError
      return true
    end
    __test_provider(Alexandria::BookProviders::LOCProvider,
                    '9780805335583')
    # this book has non-ASCII letters
    __test_provider(Alexandria::BookProviders::LOCProvider,
                    '9782070379248')
  end

  def test_BL
    begin
      require 'zoom'
    rescue LoadError
      return true
    end

    __test_provider(Alexandria::BookProviders::BLProvider,
                    '9781853260803')
  end

  def test_SBN
    begin
      require 'zoom'
    rescue LoadError
      return true
    end

    __test_provider(Alexandria::BookProviders::SBNProvider,
                    '9788835926436')
  end

  # providers supposed to be always working

  def test_bn
    __test_provider(Alexandria::BookProviders::BNProvider,
                    '9780961328917')   # see #1433
  end

  def test_mcu
    # this book is without binding information, see bug [#2533]
    __test_provider(Alexandria::BookProviders::MCUProvider,
                    '9788487982033')
    # this book is "agotado" (out of print), see bug [#2518]
    __test_provider(Alexandria::BookProviders::MCUProvider,
                    '9788496075856')
  end

  def test_proxis
    __test_provider(Alexandria::BookProviders::ProxisProvider,
                    '9789026965746')
    __test_provider(Alexandria::BookProviders::ProxisProvider,
                    '9780586071403')
  end

  def test_thalia
    # german book
    __test_provider(Alexandria::BookProviders::ThaliaProvider,
                    '9783896673305')
    # international book
    __test_provider(Alexandria::BookProviders::ThaliaProvider,
                    '9780440241904')
    # movie dvd
    __test_provider(Alexandria::BookProviders::ThaliaProvider,
                    '4010232037824')
    # music cd
    __test_provider(Alexandria::BookProviders::ThaliaProvider,
                    '0094638203520')
  end

  def test_ibs_it
    # this tests a book without image but with author
    __test_provider(Alexandria::BookProviders::IBS_itProvider,
                    '9788886973816')
    # this tests a book with image but without author
    __test_provider(Alexandria::BookProviders::IBS_itProvider,
                    '9788807710148')
  end

  def test_adlibris
    __test_provider(Alexandria::BookProviders::AdlibrisProvider,
                    '9789100109332')
  end

  def test_siciliano
    __test_provider(Alexandria::BookProviders::SicilianoProvider,
                    '9788599170380')
  end

  def test_bol
    __test_provider(Alexandria::BookProviders::BOL_itProvider,
                    '9788817012980')
  end

  def test_webster
    # BIT
    __test_provider(Alexandria::BookProviders::Webster_itProvider,
                    '9788817012980')
    # BUK
    __test_provider(Alexandria::BookProviders::Webster_itProvider,
                    '9781853260803')
    # BUS
    __test_provider(Alexandria::BookProviders::Webster_itProvider,
                    '9780307237699')
    # BDE
    __test_provider(Alexandria::BookProviders::Webster_itProvider,
                    '9783442460878')
  end

  def test_webster_multiple_authors
    this_book = __test_provider(Alexandria::BookProviders::Webster_itProvider,
                                '9788804559016')
    assert_kind_of(Array, this_book.authors, "Not an array!")
    #puts this_book.authors
    assert(this_book.authors.length == 3, "Wrong number of authors for this book!")
  end

  def test_renaud
    # adultes
    __test_provider(Alexandria::BookProviders::RENAUDProvider,
                    '9782894723388')
    # jeunesse
    __test_provider(Alexandria::BookProviders::RENAUDProvider,
                    '9782764605059')
  end

  def test_worldcat
    __test_provider(Alexandria::BookProviders::WorldcatProvider,
                    '9780521247108')
    # this one is with <div class=vernacular lang="[^"]+">)
    __test_provider(Alexandria::BookProviders::WorldcatProvider,
                    '9785941454136')
  end

  def test_worldcat_multiple_authors
    this_book = __test_provider(Alexandria::BookProviders::WorldcatProvider,
                                '9785941454136')
    assert_kind_of(Array, this_book.authors, "Not an array!")
    #puts this_book.authors
    assert(this_book.authors.length == 2, "Wrong number of authors for this book!")

  end
end
