# Copyright (C) 2005-2006 Rene Samselnig
# Copyright (C) 2007 Rene Samselnig and Marco Costantini
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

# http://de.wikipedia.org/wiki/Thalia_%28Buchhandel%29
# Thalia.de bought the Austrian book trade chain Amadeus

require 'net/http'
require 'cgi'

module Alexandria
class BookProviders
    class ThaliaProvider < GenericProvider
    
        BASE_URI = "http://www.thalia.de/"
        def initialize
            super("Thalia", "Thalia (Germany)")
            # no preferences for the moment
        end
        
        def search(criterion, type)
            criterion = criterion.convert("iso-8859-1", "utf-8")
            req = BASE_URI + "shop/bde_bu_hg_startseite/schnellsuche/buch/?"
            #if type == SEARCH_BY_ISBN
            #    req += ""
            #else
            #    req += "act=suchen&"
            #end
            req += case type
                when SEARCH_BY_ISBN
                    "fqbi="

                when SEARCH_BY_TITLE
                    "fqbt="

                when SEARCH_BY_AUTHORS
                    "fqba="

                when SEARCH_BY_KEYWORD
                    "fqbs="

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
            BASE_URI + "shop/bde_bu_hg_startseite/schnellsuche/buch/?fqbi=" + book.isbn
        end

        #######
        private
        #######
    
        def to_book(data)
						puts data if $DEBUG
						raise NoResultsError if /Leider f&uuml;hrte Ihre Suche zu keinen Ergebnissen\./.match(data) != nil
#						data = data.convert("UTF-8", "iso-8859-1")
						data = CGI::unescapeHTML(data)
						product = {}
						# title
            if md = /<span id="_artikel_titel">([^<]+)<\/span>/.match(data)
                product["title"] = md[1].strip.unpack("C*").pack("U*")
            elsif md = /<div class="standard">\n<h3>\s*(<a title=".+"><\/a>\s+)?([^<]+)<span/.match(data)
                product["title"] = md[2].strip.unpack("C*").pack("U*")
            else
                product["title"] = ""
            end
						# authors
						product["authors"] = []
						data.scan(/\/fq\w+\/([^"]+)" title="Mehr von\.\.\."><u[^>]*>([^<]+)<\/u>/) do |md|
#                next unless CGI.unescape(md[0]) == md[1]
                product["authors"] << md[1].unpack("C*").pack("U*")
            end
            #raise if product["authors"].empty?
						# isbn
            raise "No isbn" unless md = /<strong>(ISBN-13|EAN|ISBN-13\/EAN):<\/strong>\D*(\d+)<\/li>/.match(data)
            product["isbn"] = md[2].strip.gsub(/-/, "")
						# edition
            md = /<strong>Einband:<\/strong> ([^<]+)/.match(data)
            product["edition"] = md[1].strip.unpack("C*").pack("U*") if md != nil
						# publisher
            md = /<strong>Ersch(ienen|eint) +bei:<\/strong>(\&nbsp;| )(<[^>]+>)?([^<]+)/.match(data)
            product["publisher"] = md[4].strip.unpack("C*").pack("U*").split(/ /).each { |e| e.capitalize! }.join(" ") if md != nil
						# publish_year
            md = /<strong>Ersch(ienen|eint)( voraussichtlich)?:<\/strong> ([^<]+)/.match(data)
            product["publish_year"] = md[3].strip.unpack("C*").pack("U*")[-4 .. -1].to_i if md != nil
            product["publish_year"] = nil if product["publish_year"] == 0
						# cover
            if md = /<td valign="top"( nowrap)?>\n<div align="center">\n(<a href="[^>]+>)?<img (id="_artikel_mediumthumbnail" )?src="http:\/\/images\.thalia([^"]+)jpg/.match(data)
                product["cover"] = "http://images.thalia" + md[4] + "jpg"
            else
                product["cover"] = nil
            end

            book = Book.new(product["title"],
						                product["authors"],
									  				product["isbn"],
														product["publisher"],
                                                         product["publish_year"],
														product["edition"])
						return [ book, product["cover"] ]
        end

				def each_book_page(data)
				    raise if data.scan(/<a href="#{BASE_URI}(shop\/bde_bu_hg_startseite\/artikeldetails\/[^\.]+\.html)\;jsessionid=[^"]+" title="Details zu diesem Produkt sehen..."><img class="left" width="40" height="60" src="[^"]+" alt="([^"]+)" border="0">/) { |a| yield a }.empty?
				end
    end
end
end
