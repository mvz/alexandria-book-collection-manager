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

require 'amazon/search'

module Alexandria
class BookProviders
    class AmazonProvider
        attr_reader :prefs, :name 
            
        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")
       
        def initialize
            @name = "Amazon"
            @prefs = Preferences.new(@name.downcase)
            @prefs.add("locale", _("Locale site to contact"), "us",
                       Amazon::Search::LOCALES.keys)
            @prefs.add("dev_token", _("Development token"), "D23XFCO2UKJY82")
            @prefs.add("associate", _("Associate ID"), "calibanorg-20")
        end
           
        def search(criterion, type)
            prefs.read

			req = Amazon::Search::Request.new(prefs["dev_token"])
            req.locale = prefs["locale"]
			
			products = []
			case type
                when Alexandria::BookProviders::SEARCH_BY_ISBN
				    req.asin_search(criterion) { |product| products << product }
            	    raise _("Too many results") if products.length > 1 # shouldn't happen
		
                when Alexandria::BookProviders::SEARCH_BY_TITLE
				    req.keyword_search(criterion) do |product|
					    if /#{criterion}/i.match(product.product_name)
						    products << product
					    end
				    end
                
                when Alexandria::BookProviders::SEARCH_BY_AUTHORS
				    req.author_search(criterion) { |product| products << product }
                
                when Alexandria::BookProviders::SEARCH_BY_KEYWORD
				    req.keyword_search(criterion) { |product| products << product }

                else
                    raise _("Invalid search type")
			end
 
			results = []
			products.each do |product|
                next unless product.catalog == 'Book'
                conv = proc { |str| GLib.convert(str, "ISO-8859-1", "UTF-8") }
                book = Book.new(conv.call(product.product_name),
                                (product.authors.map { |x| conv.call(x) } rescue [ _("n/a") ]),
                                conv.call(product.isbn),
                                (conv.call(product.manufacturer) rescue _("n/a")),
                                conv.call(product.media))

                results << [ book, product.image_url_small, product.image_url_medium ]
            end
			type == Alexandria::BookProviders::SEARCH_BY_ISBN ? results.first : results
        end
    end
end
end
