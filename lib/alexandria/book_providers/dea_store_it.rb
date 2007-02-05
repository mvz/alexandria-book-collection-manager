# Copyright (C) 2007 Marco Costantini
# based on ibs_it.rb by Claudio Belotti
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
require 'mechanize'

module Alexandria
class BookProviders
    class DeaStore_itProvider < GenericProvider
        BASE_URI = "http://www.deastore.com"
        def initialize
            super("DeaStore_it", "DeaStore Italia")
            # no preferences for the moment
        end
        
        def search(criterion, type)
            req = BASE_URI + "/"
            req += case type
                when SEARCH_BY_ISBN
#                    "product.asp?cookie%5Ftest=1&isbn="
                     "product.asp?isbn="

                when SEARCH_BY_TITLE
                    "ricerche.asp?quick_search=ok&order_by=relevance&query_field=allbooks&query_string="

                when SEARCH_BY_AUTHORS
                    "ricerche.asp?quick_search=ok&order_by=relevance&query_field=allbooks&query_string="

                when SEARCH_BY_KEYWORD
                    "ricerche.asp?quick_search=ok&order_by=relevance&query_field=allbooks&query_string="

                else
                    raise InvalidSearchTypeError

            end
            
            req += CGI.escape(criterion)
			agent = WWW::Mechanize.new
			agent.user_agent_alias = 'Mac Safari'
	        #data = transport.get(URI.parse(req))
	        data = agent.get(URI.parse(req))
            if type == SEARCH_BY_ISBN
				#req += "&cookie%5Ftest=1"
				#data = transport.get(URI.parse(req))
				data = agent.get(URI.parse(req)) rescue data = agent.get(URI.parse(req)) #try again
                to_book(data) #rescue NoResultsError
            else
                begin
                    results = [] 
                    each_book_page(data) do |code, title|
                        #results << to_book(transport.get(URI.parse("http://www.internetbookshop.it/ser/serdsp.asp?c=" + code)))
                        results << to_book(agent.get(URI.parse("http://www.internetbookshop.it/ser/serdsp.asp?c=" + code)))
                    end
                    return results 
                rescue
                    raise NoResultsError
                end
            end
        end

        def url(book)
            return nil unless book.isbn
            "http://www.deastore.com/product.asp?cookie%5Ftest=1&isbn=" + book.isbn
        end

        #######
        private
        #######
    
        def to_book(data)
			data = data.content
            raise "No title." unless md = /<span class="BDtitoloLibro"> (.+)<\/span>/.match(data)
            title = CGI.unescape(md[1].strip)
            authors = []
	    
	        raise "Authors not found" unless md = /<span class="BDauthLibro">by:(.+)<\/span><span class="BDformatoLibro">/.match(data)
            md[1].strip.split('; ').each { |a| authors << CGI.unescape(a.strip) }
            raise "Authors are empty" if authors.empty?

            raise "No ISBN" unless md = /<span class="isbn">(.+)<\/span><br \/>/.match(data)
            isbn = md[1].strip.gsub!("-","")

            raise "No Publisher" unless md = /<span class="BDEticLibro">Publisher &amp; Imprint<\/span>(.+)<\/p>/.match(data)
	        publisher = CGI.unescape(md[1].strip)

            unless md = /<strong>More info<\/strong><\/font><br><font face="Verdana, Geneva, Arial, Helvetica, sans-serif" style="font-size : 7.5pt;" size="1">([^<]+)/.match(data)
            	edition = ""
            else
            	edition = CGI.unescape(md[1].strip)
            end
			publish_year = 0
            if data =~ /Ingrandire immagine/
	    	    small_cover = "http://www.deastore.com/covers/ie_cd1/batch1/" + isbn + ".jpg"
	    	    medium_cover = "http://www.deastore.com/covers/ie_cd1/batch2/" + isbn + ".jpg"
	    	    # big_cover = "http://www.deastore.com/covers/ie_cd1/batch3/" + isbn + ".jpg"
	            return [ Book.new(title, authors, isbn, publisher, edition),medium_cover ]
            end
	        return [ Book.new(title, authors, isbn, publisher, publish_year, edition)]
        end

        def each_book_page(data)
	        raise if data.scan(/<a href="http:\/\/www.internetbookshop.it\/ser\/serdsp.asp\?shop=1&amp;c=([\w\d]+)"><b>([^<]+)/) { |a| yield a}.empty?
        end
    end
end
end

