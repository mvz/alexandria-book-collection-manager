# Copyright (C) 2005-2006 Claudio Belotti
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
#require 'cgi'

module Alexandria
  class BookProviders
    class IBS_itProvider < GenericProvider
      BASE_URI = "http://www.internetbookshop.it"
      CACHE_DIR = File.join(Alexandria::Library::DIR, '.ibs_it_cache')
      REFERER = BASE_URI
      def initialize
        super("IBS_it", "Internet Bookshop (Italy)")
        FileUtils.mkdir_p(CACHE_DIR) unless File.exists?(CACHE_DIR)
        # no preferences for the moment
        at_exit { clean_cache }
      end

      def search(criterion, type)
        criterion = criterion.convert("ISO-8859-1", "UTF-8")
        req = BASE_URI + "/ser/"
        req += case type
               when SEARCH_BY_ISBN
                 "serdsp.asp?isbn="

               when SEARCH_BY_TITLE
                 "serpge.asp?Type=keyword&T="

               when SEARCH_BY_AUTHORS
                 "serpge.asp?Type=keyword&A="

               when SEARCH_BY_KEYWORD
                 "serpge.asp?Type=keyword&S="

               else
                 raise InvalidSearchTypeError

               end

        req += CGI.escape(criterion)
        p req if $DEBUG
        data = transport.get(URI.parse(req))
        if type == SEARCH_BY_ISBN
          to_book(data) #rescue raise NoResultsError
        else
          begin
            results = []
            each_book_page(data) do |code, title|
              results << to_book(transport.get(URI.parse("http://www.internetbookshop.it/ser/serdsp.asp?cc=" + code)))
            end
            return results
          rescue
            raise NoResultsError
          end
        end
      end

      def url(book)
        "http://www.internetbookshop.it/ser/serdsp.asp?isbn=" + book.isbn
      end

      #######
      private
      #######

      def to_book(data)
        raise NoResultsError if /<b>Il libro che hai cercato non &egrave; presente nel nostro catalogo<\/b><br>/.match(data) != nil
        data = data.convert("UTF-8", "ISO-8859-1")

        raise "No title" unless md = />Titolo<\/td><td valign="top" class="lbarrasup">([^<]+)/.match(data)
        title = CGI.unescape(md[1].strip)

        authors = []
        if md = /<b>Autore<\/b><\/td>.+<b>([^<]+)/.match(data)
          md[0].strip.gsub(/<.*?>|Autore/m, ' ').split('; ').each { |a| authors << CGI.unescape(a.strip) }
        end

        raise "No ISBN" unless md = /<input type=\"hidden\" name=\"isbn\" value=\"([^"]+)\">/i.match(data)
        isbn = md[1].strip

        #raise "No publisher" unless
        md = /<b>Editore<\/b><\/td>.+<b>([^<]+)/.match(data)
        publisher = CGI.unescape(md[1].strip) or md

        #raise "No edition" unless
        md = /Dati<\/b><\/td><td valign="top">([^<]+)/.match(data)
        edition = CGI.unescape(md[1].strip) or md

        publish_year = nil
        if md = /Anno<\/b><\/td><td valign="top">([^<]+)/.match(data)
          publish_year = CGI.unescape(md[1].strip).to_i
          publish_year = nil if publish_year == 0
        end

        md = /src="http:\/\/giotto.ibs.it\/cop\/copt13.asp\?f=(\d+)">/.match(data)
        cover_url = "http://giotto.ibs.it/cop/copt13.asp?f=" + md[1] # use copa13.asp, copt13.asp, copj13.asp, for small, medium, big image
        cover_filename = isbn + ".tmp"
        Dir.chdir(CACHE_DIR) do
          File.open(cover_filename, "w") do |file|
            file.write open(cover_url, "Referer" => REFERER ).read
          end
        end

        medium_cover = CACHE_DIR + "/" + cover_filename
        if File.size(medium_cover) > 0 and File.size(medium_cover) != 1822 # 1822 is the size of the fake image "copertina non disponibile"
          puts medium_cover + " has non-0 size" if $DEBUG
          return [ Book.new(title, authors, isbn, publisher, publish_year, edition),medium_cover ]
        end
        puts medium_cover + " has 0 size, removing ..." if $DEBUG
        File.delete(medium_cover)
        return [ Book.new(title, authors, isbn, publisher, publish_year, edition) ]
      end

      def each_book_page(data)
        raise if data.scan(/<a href="http:\/\/www.internetbookshop.it\/ser\/serdsp.asp\?shop=1&amp;cc=([\w\d]+)"><b>([^<]+)/) { |a| yield a}.empty?
      end

      def clean_cache
        #FIXME begin ... rescue ... end?
        Dir.chdir(CACHE_DIR) do
          Dir.glob("*.tmp") do |file|
            puts "removing " + file if $DEBUG
            File.delete(file)
          end
        end
      end
    end
  end
end
