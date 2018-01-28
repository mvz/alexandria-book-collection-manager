# frozen_string_literal: true

# Copyright (C) 2005-2006 Claudio Belotti
# Copyright (C) 2014, 2016 Matijs van Zuijlen
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

require 'fileutils'
require 'net/http'
require 'open-uri'
# require 'cgi'

module Alexandria
  class BookProviders
    class IBS_itProvider < GenericProvider
      BASE_URI = 'http://www.internetbookshop.it'
      CACHE_DIR = File.join(Alexandria::Library::DIR, '.ibs_it_cache')
      REFERER = BASE_URI
      def initialize
        super('IBS_it', 'Internet Bookshop (Italy)')
        FileUtils.mkdir_p(CACHE_DIR) unless File.exist?(CACHE_DIR)
        # no preferences for the moment
        at_exit { clean_cache }
      end

      def search(criterion, type)
        criterion = criterion.encode('ISO-8859-1')
        req = BASE_URI + '/ser/'
        req += case type
               when SEARCH_BY_ISBN
                 'serdsp.asp?isbn='

               when SEARCH_BY_TITLE
                 'serpge.asp?Type=keyword&T='

               when SEARCH_BY_AUTHORS
                 'serpge.asp?Type=keyword&A='

               when SEARCH_BY_KEYWORD
                 'serpge.asp?Type=keyword&S='

               else
                 raise InvalidSearchTypeError

               end

        req += CGI.escape(criterion)
        p req if $DEBUG
        data = transport.get(URI.parse(req))
        if type == SEARCH_BY_ISBN
          to_book(data) # rescue raise NoResultsError
        else
          begin
            results = []
            each_book_page(data) do |code, _title|
              uri = URI.parse('http://www.internetbookshop.it/ser/serdsp.asp?cc=' + code)
              book = to_book(transport.get(uri))
              results << book
            end
            return results
          rescue
            raise NoResultsError
          end
        end
      end

      def url(book)
        'http://www.internetbookshop.it/ser/serdsp.asp?isbn=' + book.isbn
      end

      private

      def to_book(data)
        if data =~ /<b>Il libro che hai cercato non &egrave; presente nel nostro catalogo<\/b><br>/
          raise NoResultsError
        end
        data = data.encode('UTF-8')

        md = />Titolo<\/td><td valign="top" class="lbarrasup">([^<]+)/.match(data)
        raise 'No title' unless md
        title = CGI.unescape(md[1].strip)

        authors = []
        if (md = /<b>Autore<\/b><\/td>.+<b>([^<]+)/.match(data))
          md[0].strip.gsub(/<.*?>|Autore/m, ' ').split('; ').each { |a|
            authors << CGI.unescape(a.strip)
          }
        end

        md = /<input type=\"hidden\" name=\"isbn\" value=\"([^"]+)\">/i.match(data)
        raise 'No ISBN' unless md
        isbn = md[1].strip

        # raise "No publisher" unless
        md = /<b>Editore<\/b><\/td>.+<b>([^<]+)/.match(data)
        (publisher = CGI.unescape(md[1].strip)) || md

        # raise "No edition" unless
        md = /Dati<\/b><\/td><td valign="top">([^<]+)/.match(data)
        (edition = CGI.unescape(md[1].strip)) || md

        publish_year = nil
        if (md = /Anno<\/b><\/td><td valign="top">([^<]+)/.match(data))
          publish_year = CGI.unescape(md[1].strip).to_i
          publish_year = nil if publish_year.zero?
        end

        md = /src="http:\/\/giotto.ibs.it\/cop\/copt13.asp\?f=(\d+)">/.match(data)
        # use copa13.asp, copt13.asp, copj13.asp, for small, medium, big image
        cover_url = 'http://giotto.ibs.it/cop/copt13.asp?f=' + md[1]
        cover_filename = isbn + '.tmp'
        Dir.chdir(CACHE_DIR) do
          File.open(cover_filename, 'w') do |file|
            file.write open(cover_url, 'Referer' => REFERER).read
          end
        end

        medium_cover = CACHE_DIR + '/' + cover_filename
        # 1822 is the size of the fake image "copertina non disponibile"
        if File.size(medium_cover) > 0 && (File.size(medium_cover) != 1822)
          puts medium_cover + ' has non-0 size' if $DEBUG
          return [Book.new(title, authors, isbn, publisher, publish_year, edition), medium_cover]
        end
        puts medium_cover + ' has 0 size, removing ...' if $DEBUG
        File.delete(medium_cover)
        [Book.new(title, authors, isbn, publisher, publish_year, edition)]
      end

      BOOK_PAGE_REGEXP =
        /<a href="http:\/\/www.internetbookshop.it\/ser\/serdsp.asp\?shop=1&amp;cc=([\w\d]+)"><b>([^<]+)/

      def each_book_page(data, &blk)
        result = data.scan(BOOK_PAGE_REGEXP, &blk)
        raise if result.empty?
      end

      def clean_cache
        # FIXME: begin ... rescue ... end?
        Dir.chdir(CACHE_DIR) do
          Dir.glob('*.tmp') do |file|
            puts 'removing ' + file if $DEBUG
            File.delete(file)
          end
        end
      end
    end
  end
end
