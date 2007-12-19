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

def test_provider(provider, query, search_type = Alexandria::BookProviders::SEARCH_BY_ISBN)
  results = nil

  Proc.new do
    results = provider.instance.search(query, search_type)
  end.should_not raise_error
  results.class.should == Array # "Results are not an array")
  results.should_not be_empty #, "Results are empty")
  if search_type == Alexandria::BookProviders::SEARCH_BY_ISBN
    results.length.should <= 2 #, "Results are greater than 2")
    begin
      results.first.isbn.should == query #, "Result's isbn #{results.first.isbn} is not the same as requested isbn #{query}")
    rescue
      results.first.isbn.should == Alexandria::Library.canonicalise_ean(query)
    end
    results.first.class.should == Alexandria::Book #, "Result is not a Book")
  else
    results.first.first.class.should == Alexandria::Book #, "Result item is not a Book")
  end
end

describe Alexandria do
  it "should not piss off Rich Burridge" do
    test_provider(Alexandria::BookProviders::AmazonProvider,
                  '033025068X')
  end

  it "amazon should work" do
    test_provider(Alexandria::BookProviders::AmazonProvider,
                  '9780385504201')
  end

  it "amazon title should work" do
    test_provider(Alexandria::BookProviders::AmazonProvider,
                  'A Confederacy of Dunces', Alexandria::BookProviders::SEARCH_BY_TITLE)
  end

  it "amazon authors should work" do
    test_provider(Alexandria::BookProviders::AmazonProvider,
                  'John Kennedy Toole', Alexandria::BookProviders::SEARCH_BY_AUTHORS)
  end

  it "amazon keyword should work" do
    test_provider(Alexandria::BookProviders::AmazonProvider,
                  'Confederacy Dunces', Alexandria::BookProviders::SEARCH_BY_KEYWORD)
  end

  it "dea should work" do
    test_provider(Alexandria::BookProviders::DeaStore_itProvider,
                  '9788817012980')
    test_provider(Alexandria::BookProviders::DeaStore_itProvider,
                  '9788806134747')
  end

  # Right? Don't test if dependency isn't present.

  #    def test_LOC
  #      begin
  #        require 'zoom'
  #      rescue LoadError
  #        return true
  #      end
  #      test_provider(Alexandria::BookProviders::LOCProvider,
  #                        '9780805335583')
  #      # this book has non-ASCII letters
  #      test_provider(Alexandria::BookProviders::LOCProvider,
  #                        '9782070379248')
  #    end

  #    def test_BL
  #      begin
  #        require 'zoom'
  #      rescue LoadError
  #        return true
  #      end

  #        test_provider(Alexandria::BookProviders::BLProvider,
  #                        '9781853260803')
  #    end

  #    def test_SBN
  #      begin
  #        require 'zoom'
  #      rescue LoadError
  #        return true
  #      end

  #      test_provider(Alexandria::BookProviders::SBNProvider,
  #                        '9788835926436')
  #    end

  # providers supposed to be always working

  it "bn should work" do
    test_provider(Alexandria::BookProviders::BNProvider,
                  '9780961328917')   # see #1433
  end

  it "MCU should work" do
    # this book is without binding information, see bug [#2533]
    test_provider(Alexandria::BookProviders::MCUProvider,
                  '9788487982033')
    # this book is "agotado" (out of print), see bug [#2518]
    test_provider(Alexandria::BookProviders::MCUProvider,
                  '9788496075856')
  end

  it "Proxis should work" do
    test_provider(Alexandria::BookProviders::ProxisProvider,
                  '9789026965746')
    test_provider(Alexandria::BookProviders::ProxisProvider,
                  '9780586071403')
  end

  it "Thalia should work" do
    # german book
    test_provider(Alexandria::BookProviders::ThaliaProvider,
                  '9783896673305')
    # international book
    test_provider(Alexandria::BookProviders::ThaliaProvider,
                  '9780440241904')
    # movie dvd
    test_provider(Alexandria::BookProviders::ThaliaProvider,
                  '4010232037824')
    # music cd
    test_provider(Alexandria::BookProviders::ThaliaProvider,
                  '0094638203520')
  end

  it "IBS_it should work" do
    # this tests a book without image but with author
    test_provider(Alexandria::BookProviders::IBS_itProvider,
                  '9788886973816')
    # this tests a book with image but without author
    test_provider(Alexandria::BookProviders::IBS_itProvider,
                  '9788807710148')
  end

  it "AdLibris should work" do
    test_provider(Alexandria::BookProviders::AdlibrisProvider,
                  '9789100109332')
  end

  it "Siciliano should work" do
    test_provider(Alexandria::BookProviders::SicilianoProvider,
                  '9788599170380')
  end

  it "BOL_it should work" do
    test_provider(Alexandria::BookProviders::BOL_itProvider,
                  '9788817012980')
  end

  it "Webster should work" do
    # BIT
    test_provider(Alexandria::BookProviders::Webster_itProvider,
                  '9788817012980')
    # BUK
    test_provider(Alexandria::BookProviders::Webster_itProvider,
                  '9781853260803')
    # BUS
    test_provider(Alexandria::BookProviders::Webster_itProvider,
                  '9780307237699')
    # BDE
    test_provider(Alexandria::BookProviders::Webster_itProvider,
                  '9783442460878')
  end

  it "Webster should work with multiple authors" do
    this_book = test_provider(Alexandria::BookProviders::Webster_itProvider,
                              '9788804559016')
    assert_kind_of(Array, this_book.authors, "Not an array!")
    #puts this_book.authors
    assert(this_book.authors.length == 3, "Wrong number of authors for this book!")
  end

  it "Renaud should work" do
    # adultes
    test_provider(Alexandria::BookProviders::RENAUDProvider,
                  '9782894723388')
    # jeunesse
    test_provider(Alexandria::BookProviders::RENAUDProvider,
                  '9782764605059')
  end

  it "Worldcat should work" do
    test_provider(Alexandria::BookProviders::WorldcatProvider,
                  '9780521247108')
    # this one is with <div class=vernacular lang="[^"]+">)
    test_provider(Alexandria::BookProviders::WorldcatProvider,
                  '9785941454136')
  end

  it "Worldcat should work with multiple authors" do
    this_book = test_provider(Alexandria::BookProviders::WorldcatProvider,
                              '9785941454136')
    assert_kind_of(Array, this_book.authors, "Not an array!")
    #puts this_book.authors
    assert(this_book.authors.length == 2, "Wrong number of authors for this book!")

  end
end
