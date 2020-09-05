# frozen_string_literal: true

# -*- ruby -*-
#
# Copyright (C) 2009 Cathal Mc Ginley
# Copyright (C) 2011, 2014, 2015 Matijs van Zuijlen
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

# http://en.wikipedia.org/wiki/Barnes_&_Noble

# New BarnesAndNoble provider, taken from the Palatina MetaDataSource
# and modified to fit the structure of Alexandria book providers.
# Completely rewritten by Cathal Mc Ginley (18 Dec 2009)

# NOTE: this modified version is based on the Alexandria WorldCat provider.

require "cgi"
require "alexandria/net"
require "alexandria/book_providers/web"

module Alexandria
  class BookProviders
    class BarnesAndNobleProvider < WebsiteBasedProvider
      include Logging

      SITE = "http://www.barnesandnoble.com"

      BASE_ISBN_SEARCH_URL = "http://www.barnesandnoble.com/s/%s"

      BASE_SEARCH_URL = "http://search.barnesandnoble.com/booksearch" \
        "/results.asp?%s=%s" # type, term

      def initialize
        super("BarnesAndNoble", "BarnesAndNoble")
        @agent = nil
        prefs.read
      end

      def agent
        @agent ||= Alexandria::WWWAgent.new
        @agent
      end

      def fetch_redirectly(uri_str, limit = 5)
        raise NoResultsError, _("HTTP redirect too deep") if limit.zero?

        if limit < 10
          sleep 0.1
          log.debug { "Redirectly :: #{uri_str}" }
        else
          log.debug { "Fetching   :: #{uri_str}" }
        end
        response = agent.get(uri_str)
        log.debug { response.inspect }
        case response
        when Net::HTTPSuccess then response
        when Net::HTTPRedirection
          redirect = URI.parse response["Location"]
          redirect = URI.parse(uri_str) + redirect if redirect.relative?
          fetch_redirectly(redirect.to_s, (limit - 1))
        else
          response.error!
        end
      end

      def search(criterion, type)
        req = create_search_uri(type, criterion)
        log.debug { "Requesting #{req}" }
        html_data = fetch_redirectly(req)

        if type == SEARCH_BY_ISBN
          parse_result_data(html_data.body, criterion)
        else
          results = parse_search_result_data(html_data.body)
          raise NoResultsError if results.empty?

          results.map { |result| get_book_from_search_result(result) }
        end
      end

      def url(book)
        create_search_uri(SEARCH_BY_ISBN, book.isbn)
      rescue StandardError => ex
        log.warn { "Cannot create url for book #{book}; #{ex.message}" }
        nil
      end

      def create_search_uri(search_type, search_term)
        (search_type_code = {
          SEARCH_BY_AUTHORS => "ATH",
          SEARCH_BY_TITLE   => "TTL",
          SEARCH_BY_KEYWORD => "WRD" # SEARCH_BY_PUBLISHER => 'PBL' # not implemented
        }[search_type]) || ""
        if search_type == SEARCH_BY_ISBN
          BASE_ISBN_SEARCH_URL % Library.canonicalise_ean(search_term) # isbn-13
        else
          search_term_encoded = CGI.escape(search_term)
          format(BASE_SEARCH_URL, search_type_code, search_term_encoded)
        end
      end

      def get_book_from_search_result(result)
        log.debug { "Fetching book from #{result[:url]}" }
        html_data = transport.get_response(URI.parse(result[:url]))
        parse_result_data(html_data.body)
      end

      def parse_search_result_data(html)
        doc = html_to_doc(html)
        book_search_results = []
        begin
          result_divs = doc / 'div[@class*="book-container"]'
          result_divs.each do |div|
            result = {}
            # img = div % 'div.book-image/a/img'
            # result[:image_url] = img['src'] if img
            title_header = div % "h2"
            title_links = title_header / "a"
            result[:title] = title_links.first.inner_text
            result[:url] = title_links.first["href"]

            book_search_results << result
          end
        rescue StandardError => ex
          trace = ex.backtrace.join("\n> ")
          log.warn do
            "Failed parsing search results for Barnes & Noble " \
            "#{ex.message} #{trace}"
          end
        end
        book_search_results
      end

      def parse_result_data(html, _search_isbn = nil, _recursing = false)
        doc = html_to_doc(html)
        begin
          book_data = {}

          dl = (doc / "dl").first
          dts = dl.children_of_type("dt")
          dts.each do |dt|
            value = dt.next_sibling.inner_text
            case dt.inner_text
            when /ISBN-13/
              book_data[:isbn] = Library.canonicalise_ean(value)
            when /Publisher/
              book_data[:publisher] = value
            when /Publication data/
              value =~ /\d{2}.\d{2}.(\d{4})/
              year = Regexp.last_match[1]
              book_data[:publisher] = year
            end
          end

          meta = doc / "meta"
          meta.each do |it|
            attrs = it.attributes
            property = attrs["property"]
            next unless property

            case property
            when "og:title"
              book_data[:title] = attrs["content"]
            when "og:image"
              book_data[:image_url] = attrs["content"]
            end
          end

          author_links = doc / "span.contributors a"
          authors = author_links.map(&:inner_text)
          book_data[:authors] = authors

          book_data[:binding] = ""
          selected_format = (doc / "#availableFormats li.selected a.tabTitle").first
          book_data[:binding] = selected_format.inner_text if selected_format

          book = Book.new(book_data[:title], book_data[:authors],
                          book_data[:isbn], book_data[:publisher],
                          book_data[:publication_year],
                          book_data[:binding])
          [book, book_data[:image_url]]
        rescue StandardError => ex
          raise ex if ex.instance_of? NoResultsError

          trace = ex.backtrace.join("\n> ")
          log.warn do
            "Failed parsing search results for BarnesAndNoble " \
            "#{ex.message} #{trace}"
          end
          raise NoResultsError
        end
      end
    end
  end
end
