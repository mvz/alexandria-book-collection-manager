# Copyright (C) 2005 Claudio Belotti
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
#require 'cgi'

module Alexandria
class BookProviders
    class IBS_itProvider < GenericProvider
        BASE_URI = "http://www.internetbookshop.it"
        def initialize
            super("IBS_it", "Internet Bookshop Italia")
            # no preferences for the moment
        end
        
        def search(criterion, type)
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
	        data = transport.get(URI.parse(req))
            if type == SEARCH_BY_ISBN
                to_book(data) rescue raise NoResultsError
            else
                begin
                    results = [] 
                    each_book_page(data) do |code, title|
                        results << to_book(transport.get(URI.parse("http://www.internetbookshop.it/ser/serdsp.asp?c=" + code)))
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
            raise unless md = /<b>Titolo<\/b><\/td><td valign="top"><span class="lbarrasup">([^<]+)/.match(data)
            title = CGI.unescape(md[1].strip)
            authors = []
	    
	        md = /<b>Autore<\/b><\/td>.+<b>([^<]+)/.match(data)
            md[1].split(';').each { |a| authors << CGI.unescape(a.strip) }
            raise if authors.empty?

            raise unless md = /<input type=\"hidden\" name=\"isbn\" value=\"([^"]+)\">/i.match(data)
            isbn = md[1].strip

            raise unless md = /<b>Editore<\/b><\/td>.+<b>([^<]+)/.match(data)
	        publisher = CGI.unescape(md[1].strip)

            raise unless md = /Dati<\/b><\/td><td valign="top">([^<]+)/.match(data)
            edition = CGI.unescape(md[1].strip)

            if data =~ /src\=\"http:\/\/giotto.ibs.it\/thumbnails\/(.+\.jpg)\">/
	    	    small_cover = "http://giotto.ibs.it/thumbnails/" + $1
	    	    medium_cover = "http://giotto.ibs.it/jackets/" + $1
	            return [ Book.new(title, authors, isbn, publisher, edition),medium_cover ]
            end
	        return [ Book.new(title, authors, isbn, publisher, edition)]
        end

        def each_book_page(data)
	        raise if data.scan(/<a href="http:\/\/www.internetbookshop.it\/ser\/serdsp.asp\?shop=1&amp;c=([\w\d]+)"><b>([^<]+)/) { |a| yield a}.empty?
        end
    end
end
end
