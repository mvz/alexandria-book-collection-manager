# Copyright (C) 2004 Laurent Sansonetti
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

require 'net/http'
require 'cgi'

module Alexandria
class BookProviders
    class BNProvider < GenericProvider
    
        BASE_URI = "http://search.barnesandnoble.com/"
        def initialize
            super("BN", "Barnes and Noble")
            # no preferences for the moment
        end
        
        def search(criterion, type)
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
            raise unless md = /<sup>&nbsp;<\/sup><font size="-1" color="#006666" face="arial, helvetica, sans-serif"><b>([^<]+)<\/b><\/font>/.match(data)
            title = md[1].strip
            authors = []
            data.scan(/<a href="\/booksearch\/results.asp\?userid=[\w\d]+&ath=([^"]+)\">([^<]+)<\/a>/) do |md|
                next unless CGI.unescape(md[0]) == md[1]
                authors << md[1]
            end
            raise if authors.empty?
            raise unless md = /<B>ISBN:<\/B><\/nobr>([^<]+)/.match(data)
            isbn = md[1].strip
            raise unless md = /<B>Format:<\/B><\/nobr>([^<]+)/.match(data)
            edition = md[1].strip
            raise unless md = /<B>Publisher:<\/B><\/nobr>([^<]+)/.match(data)
            publisher = md[1].strip
            raise unless md = /<IMG SRC="(.+\/(\d+).gif)" ALT="Book Cover" WIDTH="100" HEIGHT="\d+" BORDER="0">/.match(data)
            medium_cover = md[1]
            small_cover = medium_cover.sub(/#{md[2]}/, (md[2].to_i - 1).to_s)
            [ Book.new(title, authors, isbn, publisher, edition), small_cover, medium_cover ]
        end
    
        def each_book_page(data)
            raise if data.scan(/<A href="(\/booksearch\/isbnInquiry.asp\?userid=[\w\d]+&isbn=[^"]+)">([^<]+)<\/A>/) { |a| yield a }.empty?
        end
    end
end
end
