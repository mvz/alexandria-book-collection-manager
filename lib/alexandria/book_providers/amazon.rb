# Copyright (C) 2004-2006 Laurent Sansonetti
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

        CACHE_DIR = File.join(Alexandria::Library::DIR, '.amazon_cache')
        
        def initialize
            super("Amazon")
            prefs.add("locale", _("Locale"), "us",
                       Amazon::Search::LOCALES.keys)
            prefs.add("dev_token", _("Development token"), 
                      "142TF8CHT48WYPPS6J82")
            prefs.add("associate", _("Associate ID"), "calibanorg-20", nil, 
                      false)
            
            # Backward compatibility hack - the previous developer token has 
            # been revoked.
            prefs.read
            token = prefs.variable_named("dev_token")
            if token and token.value == "D23XFCO2UKJY82"
                token.new_value = "142TF8CHT48WYPPS6J82"
            end
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
            req.cache = Amazon::Search::Cache.new(CACHE_DIR)
            locales = Amazon::Search::LOCALES.keys
            locales.delete prefs["locale"]
            locales.unshift prefs["locale"]
            locales.reverse!

            begin
                req.locale = locales.pop
                products = []
                case type
                    when SEARCH_BY_ISBN
                        req.asin_search(criterion) do |product| 
                            products << product
                        end
                        # shouldn't happen
                        raise TooManyResultsError if products.length > 1 

                    when SEARCH_BY_TITLE
                        req.keyword_search(criterion) do |product|
                            if /#{criterion}/i.match(product.product_name)
                                products << product
                            end
                        end

                    when SEARCH_BY_AUTHORS
                        req.author_search(criterion) do |product| 
                            products << product
                        end

                    when SEARCH_BY_KEYWORD
                        req.keyword_search(criterion) do |product|
                            products << product
                        end

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
                title = product.product_name.squeeze(' ')
                
                # Work around Amazon US encoding bug. Amazon US apparently
                # interprets UTF-8 titles as ISO-8859 titles and then converts
                # the garbled titles to UTF-8. This tries to convert back into
                # valid UTF-8. It does not always work - see isbn 2259196098
                # (from the mailing list) for an example.
                #if req.locale == 'us'
                #    title = title.convert('iso-8859-1','utf-8') 
                #end

                book = Book.new(title,
                                (product.authors.map { |x| x.squeeze(' ') } \
                                    rescue [ _("n/a") ]),
                                product.isbn.squeeze(' '),
                                (product.manufacturer.squeeze(' ') \
                                    rescue _("n/a")),
                                (Time.parse(product.release_date).year \
                                    rescue nil),
                                product.media.squeeze(' '))

                results << [ book, product.image_url_medium ]
            end
            type == SEARCH_BY_ISBN ? results.first : results
        end

        def url(book)
            return nil unless book.isbn
            url = case prefs["locale"]
                when "fr"
                    "http://www.amazon.fr/exec/obidos/ASIN/%s"
                when "uk"    
                    "http://www.amazon.co.uk/exec/obidos/ASIN/%s"
                when "de"
                    "http://www.amazon.de/exec/obidos/ASIN/%s"
                when "ca"
                    "http://www.amazon.ca/exec/obidos/ASIN/%s"
                when "jp"
                    "http://www.amazon.jp/exec/obidos/ASIN/%s"
                when "us"
                    "http://www.amazon.com/exec/obidos/ASIN/%s"
            end
            url % book.isbn
        end
    end
end
end
