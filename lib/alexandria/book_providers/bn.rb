# Copyright (C) 2004-2006 Laurent Sansonetti
# Copyright (C) 2007 Laurent Sansonetti and Marco Costantini
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
# write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

# http://en.wikipedia.org/wiki/Barnes_&_Noble

require 'net/http'
require 'cgi'

module Alexandria
class BookProviders
    class BNProvider < GenericProvider
    
        BASE_URI = "http://search.barnesandnoble.com/"
        def initialize
            super("BN", "Barnes and Noble (Usa)")
            # no preferences for the moment
        end
        
        def search(criterion, type)
            criterion = criterion.convert("ISO-8859-1", "UTF-8")
            req = BASE_URI + "booksearch/"
            req += case type
                when SEARCH_BY_ISBN
                    "isbninquiry.asp?ISBN="

                when SEARCH_BY_TITLE
                    "results.asp?TTL="

                when SEARCH_BY_AUTHORS
                    "results.asp?ATH="

                when SEARCH_BY_KEYWORD
                    "results.asp?WRD="

                else
                    raise InvalidSearchTypeError

            end

            req += CGI.escape(criterion)
            puts req if $DEBUG
            data = transport.get(URI.parse(req))
            if type == SEARCH_BY_ISBN
                to_book(data) rescue raise NoResultsError
            else
                begin
                    results = [] 
                    each_book_page(data) do |page, title|
                        results << to_book(transport.get(URI.parse(BASE_URI + page)))
                    end
                    return results 
                rescue
                    raise NoResultsError
                end
            end
        end

        def url(book)
            "http://search.barnesandnoble.com/booksearch/isbninquiry.asp?ISBN=" + book.isbn
        end

        #######
        private
        #######
    
        def to_book(data)
            raise NoResultsError if /<body><h1>Object Moved<\/h1>This object may be found <a HREF="http:\/\/www.barnesandnoble.com\/booksearch\/noresults.asp/.match(data) != nil
            data = data.convert("UTF-8", "ISO-8859-1")

            raise "No title" unless md = /Barnes&nbsp;&amp;&nbsp;Noble.com - Books: ([^<]+)/.match(data)
            title = md[1].strip

            authors = []
            data.scan(/<a href="\/booksearch\/results.asp\?ATH\=([^"]+)\&amp;z=y">\s*([^<]+)/) do |md|
                md[1].gsub!('&nbsp;',' ')
                next unless CGI.unescape(md[0]) == md[1]
                authors << md[1]
            end

            raise "No ISBN" unless md = /ISBN-13:\s+<a style="text-decoration:none">([^<]+)/.match(data)
            isbn = md[1].strip

            #raise unless 
            md = /<li class="publisher">Publisher:\s+([^<]+)/.match(data)
            publisher = md[1].strip or md

            #raise unless 
            md = /<li class="format">Format:\s+([^<]+)/.match(data)
            edition = md[1].strip or md

            publish_year = nil
            if md = /<li class="pubDate">Pub. Date:[^<]+(\d\d\d\d)</.match(data)
                publish_year = md[1].to_i
                publish_year = nil if publish_year == 0
            end

          if md = /<IMG SRC="(.+\/(\d+|ImageNA_product).gif)" ALT=("Book Cover"|"Image Not Available") WIDTH="\d+" HEIGHT="\d+" BORDER="0">/.match(data)
            medium_cover = md[1]
            small_cover = medium_cover.sub(/#{md[2]}/, (md[2].to_i - 1).to_s)
            return [ Book.new(title, authors, isbn, publisher, publish_year, 
                     edition), medium_cover ]
          else return [ Book.new(title, authors, isbn, publisher, publish_year, edition) ]
          end
        end
    
        def each_book_page(data)
            raise if data.scan(/<A href="(\/booksearch\/isbnInquiry.asp\?userid=[\w\d]+&isbn=[^"]+)">([^<]+)<\/A>/) { |a| yield a }.empty?
        end
    end
end
end
