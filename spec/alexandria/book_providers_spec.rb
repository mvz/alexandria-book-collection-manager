# Copyright (C) 2005-2006 Laurent Sansonetti
# Copyright (C) 2007 Joseph Method
# Copyright (C) 2011, 2014, 2015 Matijs van Zuijlen
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

require 'spec_helper'

describe Alexandria::BookProviders do
  it 'should be less clever'

  def assert_correct_search_result(provider, query,
                                   search_type = Alexandria::BookProviders::SEARCH_BY_ISBN)
    begin
      results = provider.instance.search(query, search_type)
    rescue SocketError
      skip 'Service is offline'
    end

    puts results.inspect if $DEBUG

    expect(results).to be_instance_of(Array), "Results are not an array for #{provider}"
    expect(results).not_to be_empty, "Results are empty for #{provider}"

    if search_type == Alexandria::BookProviders::SEARCH_BY_ISBN
      expect(results.length).to be <= 2, "Results are greater than 2 for #{provider}"

      book = results.first

      expect(book).to be_instance_of(Alexandria::Book), "Result is not a Book for #{provider}"

      canonical_query = Alexandria::Library.canonicalise_ean(query)
      canonical_result = Alexandria::Library.canonicalise_ean(book.isbn)
      expect(canonical_query).
        to eq(canonical_result),
           "Result's isbn #{book.isbn} is not equivalent to the requested isbn #{query} for #{provider}"

      if results.length == 2
        cover_url = results.last
        if cover_url
          expect(cover_url).
            to be_instance_of(String), "Unexpected cover_url #{cover_url.inspect} for #{provider}"
        end
      end
    else
      expect(results.first.first).
        to be_instance_of(Alexandria::Book), "Result item is not a Book for #{provider}"
    end
    results
  end

  it 'should not piss off Rich Burridge' do
    skip 'Amazon requires an API key. Remove it altogether as a provider?'
    assert_correct_search_result(Alexandria::BookProviders::AmazonProvider,
                                 '033025068X')
  end

  it 'amazon should work' do
    skip 'Amazon requires an API key. Remove it altogether as a provider?'
    assert_correct_search_result(Alexandria::BookProviders::AmazonProvider,
                                 '9780385504201')
  end

  it 'amazon title should work' do
    skip 'Amazon requires an API key. Remove it altogether as a provider?'
    assert_correct_search_result(Alexandria::BookProviders::AmazonProvider,
                                 'A Confederacy of Dunces', Alexandria::BookProviders::SEARCH_BY_TITLE)
  end

  it 'amazon authors should work' do
    skip 'Amazon requires an API key. Remove it altogether as a provider?'
    assert_correct_search_result(Alexandria::BookProviders::AmazonProvider,
                                 'John Kennedy Toole', Alexandria::BookProviders::SEARCH_BY_AUTHORS)
  end

  it 'amazon keyword should work' do
    skip 'Amazon requires an API key. Remove it altogether as a provider?'
    assert_correct_search_result(Alexandria::BookProviders::AmazonProvider,
                                 'Confederacy Dunces', Alexandria::BookProviders::SEARCH_BY_KEYWORD)
  end

  it 'dea should work' do
    skip 'DEAStore is not operational at the moment'
    assert_correct_search_result(Alexandria::BookProviders::DeaStoreProvider,
                                 '9788817012980')
    assert_correct_search_result(Alexandria::BookProviders::DeaStoreProvider,
                                 '9788806134747')
  end

  # Right? Don't test if dependency isn't present.

  it 'LOC should work' do
    assert_correct_search_result(Alexandria::BookProviders::LOCProvider,
                                 '9780805335583')
    # this book has non-ASCII letters
    assert_correct_search_result(Alexandria::BookProviders::LOCProvider,
                                 '9782070379248')
  end

  it 'BL should work' do
    assert_correct_search_result(Alexandria::BookProviders::BLProvider,
                                 '9781853260803')
  end

  it 'SBN should work' do
    assert_correct_search_result(Alexandria::BookProviders::SBNProvider,
                                 '9788835926436')
  end

  it 'Barnes and Noble should work' do
    skip 'Barnes and Noble is not operational at the moment'
    assert_correct_search_result(Alexandria::BookProviders::BarnesAndNobleProvider,
                                 '9780961328917') # see #1433
  end

  it 'MCU should work' do
    skip 'Needs fixing'
    # this book is without binding information, see bug [#2533]
    assert_correct_search_result(Alexandria::BookProviders::MCUProvider,
                                 '9788487982033')
    # this book is "agotado" (out of print), see bug [#2518]
    assert_correct_search_result(Alexandria::BookProviders::MCUProvider,
                                 '9788496075856')
  end

  it 'Proxis should work' do
    skip 'Needs fixing'
    assert_correct_search_result(Alexandria::BookProviders::ProxisProvider,
                                 '9789026965746')
    assert_correct_search_result(Alexandria::BookProviders::ProxisProvider,
                                 '9780586071403')
  end

  it 'Thalia should work' do
    skip 'Needs fixing'
    # german book
    assert_correct_search_result(Alexandria::BookProviders::ThaliaProvider,
                                 '9783896673305')
    # international book
    assert_correct_search_result(Alexandria::BookProviders::ThaliaProvider,
                                 '9780440241904')
    # movie dvd
    assert_correct_search_result(Alexandria::BookProviders::ThaliaProvider,
                                 '4010232037824')
    # music cd
    assert_correct_search_result(Alexandria::BookProviders::ThaliaProvider,
                                 '0094638203520')
  end

  it 'IBS_it should work' do
    skip 'Marked in code as not working; remove implementation entirely.'
    # this tests a book without image but with author
    assert_correct_search_result(Alexandria::BookProviders::IBS_itProvider,
                                 '9788886973816')
    # this tests a book with image but without author
    assert_correct_search_result(Alexandria::BookProviders::IBS_itProvider,
                                 '9788807710148')
  end

  it 'AdLibris should work' do
    skip 'Needs fixing: site has changed'
    assert_correct_search_result(Alexandria::BookProviders::AdLibrisProvider,
                                 '9789100109332')
  end

  it 'Siciliano should work' do
    skip 'Needs fixing: no results found'
    assert_correct_search_result(Alexandria::BookProviders::SicilianoProvider,
                                 '9788599170380')
  end

  it 'BOL_it should work' do
    skip 'Marked in code as not working; remove implementation entirely.'
    assert_correct_search_result(Alexandria::BookProviders::BOL_itProvider,
                                 '9788817012980')
  end

  it 'Webster should work' do
    skip 'Marked in code as not working; remove implementation entirely.'
    # BIT
    assert_correct_search_result(Alexandria::BookProviders::Webster_itProvider,
                                 '9788817012980')
    # BUK
    assert_correct_search_result(Alexandria::BookProviders::Webster_itProvider,
                                 '9781853260803')
    # BUS
    assert_correct_search_result(Alexandria::BookProviders::Webster_itProvider,
                                 '9780307237699')
    # BDE
    assert_correct_search_result(Alexandria::BookProviders::Webster_itProvider,
                                 '9783442460878')
  end

  it 'Webster should work with multiple authors' do
    skip 'Marked in code as not working; remove implementation entirely.'
    this_book = assert_correct_search_result(Alexandria::BookProviders::Webster_itProvider,
                                             '9788804559016')
    assert_kind_of(Array, this_book.authors, 'Not an array!')
    # puts this_book.authors
    assert(this_book.authors.length == 3, 'Wrong number of authors for this book!')
  end

  it 'Renaud should work' do
    skip 'Marked in code as not working; remove implementation entirely.'
    # adultes
    assert_correct_search_result(Alexandria::BookProviders::RENAUDProvider,
                                 '9782894723388')
    # jeunesse
    assert_correct_search_result(Alexandria::BookProviders::RENAUDProvider,
                                 '9782764605059')
  end

  it 'Worldcat should work' do
    assert_correct_search_result(Alexandria::BookProviders::WorldCatProvider,
                                 '9780521247108')
    # this one is with <div class=vernacular lang="[^"]+">)
    assert_correct_search_result(Alexandria::BookProviders::WorldCatProvider,
                                 '9785941454136')
  end

  it 'Worldcat should work with multiple authors' do
    results = assert_correct_search_result(Alexandria::BookProviders::WorldCatProvider,
                                           '9785941454136')
    this_book = results.first
    expect(this_book.authors).to be_instance_of(Array), 'Not an array!'
    # puts this_book.authors
    expect(this_book.authors.length).to eq(2), 'Wrong number of authors for this book!'
  end
end
