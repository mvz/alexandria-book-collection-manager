# Copyright (C) 2005 Rene Samselnig - Modified by Linus Zetterlund
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

# TODO:
# fix едц


require 'net/http'
require 'cgi'

module Alexandria
class BookProviders
    class AdlibrisProvider < GenericProvider
        BASE_URI = "http://www.adlibris.se/"
        def initialize
            super("Adlibris", "Adlibris (Sweden)")
            # no preferences for the moment
        end
        
        def search(criterion, type)
            criterion = criterion.convert("iso-8859-1", "utf-8")
            req = BASE_URI
            if type == SEARCH_BY_ISBN
                req += "product.aspx?isbn="+criterion+"&checked=1"
            else
				search_criterions = {}
				search_criterions[type] = CGI.escape(criterion)
				req = "http://www.adlibris.se/shop/search_result.asp?additem=&page=search%5Fresult%2Easp&search=advanced&format=&status=&ebook=&quickvalue=&quicktype=&isbn="+ search_criterions[SEARCH_BY_ISBN] + "&titleorauthor=&title="+search_criterions[SEARCH_BY_TITLE].to_s()+"&authorlast=&authorfirst=&keyword="+search_criterions[SEARCH_BY_KEYWORD].to_s()+"&publisher=&category=&language=&inventory1=1&inventory2=2&inventory4=4&inventory8=&get=&type=&sortorder=1&author="+search_criterions[SEARCH_BY_AUTHORS].to_s()+"&checked=1"
			end


			results = []
			
            if type == SEARCH_BY_ISBN
				data = transport.get(URI.parse(req))
				#puts URI.parse(req)
				#puts "if type == SEARCH_BY_ISBN"
				return to_book_isbn(data, criterion) #rescue raise NoResultsError
            else
                begin
					data = transport.get(URI.parse(req+"&row=1"))
					
					regx = /shop\/product\.asp\?isbn=([^&]+?)&[^>]+>([^<]+?)<\/a>([^>]*?>){10}([^<]+?)<\/b>[^\)]+?\);\"\)>[\s]+?([^<\s]+?)<\/a>/
					
					begin
					data.scan(regx) do |md| next unless md[0] != md[1]
						
						isbn = md[0].to_s()

						imageAddr = nil
 						imgAddrMatch = data.scan(isbn+'.jpg')
						if imgAddrMatch.length() == 2
							imageAddr = 'http://www.adlibris.se/shop/images/'+isbn+'.jpg'
						end
												
						results << [Book.new(md[1].to_s(), # Title
							[md[3].to_s()], # Authors
							isbn,
							nil, # Publisher
							translate_stuff_stuff(md[4].to_s())), # Edition
							imageAddr]
					end
					rescue => e
						puts e.message
					end
					
					return results
                rescue
                    raise NoResultsError
                end
            end
        end

        def url(book)
			#puts "debug: url(book)"
            BASE_URI + "product.aspx?isbn=" + book.isbn
        end

        #######
        private
        #######
		
		def translate_html_stuff!(r)
			r.sub!('&#229;','ГҐ') # е
			r.sub!('&#228;','Г¤') # д
			r.sub!('&#246;','Г¶') # ц
			r.sub!('&#197;','Г.') # Е
			r.sub!('&#196;','Г.') # Д
			r.sub!('&#214;','Г.') # Ц
			return r
		end
		def translate_html_stuff(s)
			r = s
			translate_html_stuff!(r)
			return r
		end


		def translate_stuff_stuff!(r)
			#r.sub!('\е','ГҐ') # е
			#r.sub!('\д','Г¤') # д
			#r.sub!('\ц','Г¶') # ц
			#r.sub!('\Е','Г.') # Е
			#r.sub!('\Д','Г.') # Д
			#r.sub!('\Ц','Г.') # Ц
			return r
		end
		def translate_stuff_stuff(s)
			r = s
			translate_stuff_stuff!(r)
			return r
		end

		
		def to_book_isbn(data, isbn)
			#puts data
			data = data.convert("UTF-8", "iso-8859-1")

			product = {}			
			if /Ingen titel med detta ISBN finns hos AdLibris/.match(data) != nil
				raise NoResultsError
			end


			raise "Title not found" unless md = /<a id="ctl00_main_frame_ctrlproduct_linkProductTitle" class="header15">(.+)<\/a>/.match(data)
			
			product["title"] = CGI.unescape(md[1])


#			regx = /<tr><td colspan="2" class="text">F&#246;rfattare:&nbsp;<b>([^<]*)<\/b><\/td><\/tr>/
			regx = /<tr><td colspan="2" class="text">F.rfattare:&nbsp;<b>([^<]*)<\/b><\/td><\/tr>/
			product["authors"] = []
			data.scan(regx) do |md| next unless md[0] != md[1]
    			product["authors"] << translate_html_stuff(CGI.unescape(md[0]))
			end
			
			#raise "Publisher string not found, but no \"book not found\" string found\n" unless 
			md = /<span id="ctl00_main_frame_ctrlproduct_lblPublisherName">(.+)<\/span>/.match(data)
			
			product["publisher"] = md[1] or md #i.e., or nil


			#raise "No edition" unless 
			md = /<span id="ctl00_main_frame_ctrlproduct_lblEditionAndWeight">([^<]*)i gram: .+<\/span>/.match(data)
			
			product["edition"] = md[1] or md

			isbn10 = Library.canonicalise_isbn(isbn)
			img_url = "covers/" + isbn10[0 .. 0] + "/" + isbn10[1 .. 2] + "/" + isbn10 + ".jpg"
			#puts img_url
			#raise "No image found" unless md = data.match(img_url)
			product["cover"] = BASE_URI + img_url
						
			book = Book.new(
				translate_html_stuff(product["title"]),
				product["authors"],
				Library.canonicalise_ean(isbn),
				translate_html_stuff(product["publisher"]),
				publish_year = 0,
				translate_html_stuff(product["edition"]))
			return [ book, product["cover"] ]
		end

    end
end
end
