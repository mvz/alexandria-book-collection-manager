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
    class AmazonProvider < GenericProvider
        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")
        
        def initialize
            super("Amazon")
            prefs.add("locale", _("Locale site to contact"), "us",
                       Amazon::Search::LOCALES.keys)
            prefs.add("dev_token", _("Development token"), "D23XFCO2UKJY82")
            prefs.add("associate", _("Associate ID"), "calibanorg-20")
        end
           
        def search(criterion, type)
            prefs.read

            if config = Alexandria::Preferences.instance.http_proxy_config
                host, port, user, pass = config
                url = "http://"
                url += user + ":" + pass + "@" if user and pass
                url += host + ":" + port.to_s
                ENV['http_proxy'] = url
            end

			req = Amazon::Search::Request.new(prefs["dev_token"])
            locales = Amazon::Search::LOCALES.keys
            locales.delete prefs["locale"]
            locales.unshift prefs["locale"]
            locales.reverse!

            begin		
                req.locale = locales.pop
    			products = []
    			case type
                    when SEARCH_BY_ISBN
    				    req.asin_search(criterion) { |product| products << product }
                	    raise TooManyResultsError if products.length > 1 # shouldn't happen
    		
                    when SEARCH_BY_TITLE
    				    req.keyword_search(criterion) do |product|
    					    if /#{criterion}/i.match(product.product_name)
    						    products << product
    					    end
    				    end
                    
                    when SEARCH_BY_AUTHORS
    				    req.author_search(criterion) { |product| products << product }
                    
                    when SEARCH_BY_KEYWORD
    				    req.keyword_search(criterion) { |product| products << product }
    
                    else
                        raise InvalidSearchTypeError
    			end
                raise NoResultsError if products.empty?
            rescue Amazon::Search::Request::SearchError
                retry unless locales.empty?
                raise NoResultsError
            end
 
			results = []
			products.each do |product|
                next unless product.catalog == 'Book'
                conv = proc do |str|
                    # FIXME looks like we don't need to decode the charset anymore
                    # should fix that ASAP
                    GLib.convert(str.squeeze(' '), "ISO-8859-1", "UTF-8")
                end 
                book = Book.new(conv.call(product.product_name),
                                (product.authors.map { |x| conv.call(x) } rescue [ _("n/a") ]),
                                conv.call(product.isbn),
                                (conv.call(product.manufacturer) rescue _("n/a")),
                                conv.call(product.media))

                results << [ book, product.image_url_small, product.image_url_medium ]
            end
            type == SEARCH_BY_ISBN ? results.first : results
        end
    end
end
end
