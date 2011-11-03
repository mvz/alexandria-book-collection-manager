# Copyright (C) 2004-2006 Laurent Sansonetti
# Copyright (C) 2008 Cathal Mc Ginley
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

# http://en.wikipedia.org/wiki/Amazon

require 'alexandria/book_providers/amazon_ecs_util'

module Alexandria
  class BookProviders
    class AmazonProvider < GenericProvider
      include Logging
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")

      #CACHE_DIR = File.join(Alexandria::Library::DIR, '.amazon_cache')

      LOCALES = ['ca','de','fr','jp','uk','us']

      def initialize
        super("Amazon", "Amazon")
        # prefs.add("enabled", _("Enabled"), true, [true,false])
        prefs.add("locale", _("Locale"), "us", AmazonProvider::LOCALES)
        prefs.add("dev_token", _("Access key ID"), '')
        prefs.add("secret_key", _("Secret access key"), '')
        prefs.add("associate_tag", _("Associate Tag"), '')

        prefs.read
        token = prefs.variable_named("dev_token")        
        # kill old (shorter) tokens, or previously distributed Access Key Id (see #26250)

        if token
          if (token.value != token.value.strip)
            token.new_value = token.value.strip
          end
        end
        if token and (token.value.size != 20 or token.value == '0J356Z09CN88KB743582')
          token.new_value = ''           
        end

        secret = prefs.variable_named("secret_key")
        if secret
          if (secret.value != secret.value.strip)
            secret.new_value = secret.value.strip
          end
        end

        associate = prefs.variable_named("associate_tag")
        if associate
          if associate.value.strip.empty?
            associate.new_value = 'rubyalexa-20'
          end
          if (associate.value != associate.value.strip)
            associate.new_value = associate.value.strip
          end          
        end


      end

      def search(criterion, type)
        prefs.read

        if prefs["secret_key"].empty?
          raise Amazon::RequestError.new("Secret Access Key required for Authentication: you must sign up for your own Amazon AWS account")
        end
        
        if config = Alexandria::Preferences.instance.http_proxy_config
          host, port, user, pass = config
          url = "http://"
          url += user + ":" + pass + "@" if user and pass
          url += host + ":" + port.to_s
          ENV['http_proxy'] = url
        end

        access_key_id = prefs["dev_token"]

        Amazon::Ecs.options = {:aWS_access_key_id => access_key_id,
                               :associateTag => prefs["associate_tag"]}
        Amazon::Ecs.secret_access_key = prefs["secret_key"]
        ##req.cache = Amazon::Search::Cache.new(CACHE_DIR)
        locales = AmazonProvider::LOCALES.dup
        locales.delete prefs["locale"]
        locales.unshift prefs["locale"]
        locales.reverse!

        begin
          request_locale = locales.pop.intern
          products = []
          case type
          when SEARCH_BY_ISBN
            criterion = Library.canonicalise_isbn(criterion)
            # This isn't ideal : I'd like to do an ISBN/EAN-specific search
            res = Amazon::Ecs.item_search(criterion, {:response_group =>'ItemAttributes,Images', :country => request_locale})
            res.items.each do |item|
              products << item
            end
            ##req.asin_search(criterion) do |product|

            # Shouldn't happen.
            # raise TooManyResultsError if products.length > 1

            # I had assumed that publishers were bogusly publishing
            # multiple editions of a book with the same ISBN, and
            # Amazon was distinguishing between them.  So we'll log
            # this case, and arbitrarily return the FIRST item
            
            # Actually, this may be due to Amazon recommending a
            # preferred later edition of a book, in spite of our
            # searching on a single ISBN it can return more than one
            # result with different ISBNs
            
            if products.length > 1
              log.warn { "ISBN search at Amazon[#{request_locale}] got #{products.length} results; returning the first result only" }
            end

          when SEARCH_BY_TITLE
            res = Amazon::Ecs.item_search(criterion, {:response_group =>'ItemAttributes,Images', :country => request_locale})

            res.items.each do |item|
              if /#{criterion}/i.match(item.get('itemattributes/title'))
                products << item
              end
            end
            ##req.keyword_search(criterion) do |product|

          when SEARCH_BY_AUTHORS
            criterion = "author:#{criterion}"
            res = Amazon::Ecs.item_search(criterion, {:response_group =>'ItemAttributes,Images', :country => request_locale, :type => 'Power'})
            res.items.each do |item|
              products << item
            end
            ##req.author_search(criterion) do |product|

          when SEARCH_BY_KEYWORD
            res = Amazon::Ecs.item_search(criterion, {:response_group =>'ItemAttributes,Images', :country => request_locale})

            res.items.each do |item|
              products << item
            end

          else
            raise InvalidSearchTypeError
          end
          if products.empty?
            raise Amazon::RequestError, "No products"
          end
          # raise NoResultsError if products.empty?
        rescue Amazon::RequestError => re
          log.debug { "Got Amazon::RequestError at #{request_locale}: #{re}"}
          retry unless locales.empty?
          raise NoResultsError
        end

        results = []
        products.each do |item|
          next unless item.get('itemattributes/productgroup') == 'Book'
          atts = item.search_and_convert('itemattributes')
          title = normalize(atts.get('title'))

          # Work around Amazon US encoding bug. Amazon US apparently
          # interprets UTF-8 titles as ISO-8859 titles and then converts
          # the garbled titles to UTF-8. This tries to convert back into
          # valid UTF-8. It does not always work - see isbn 2259196098
          # (from the mailing list) for an example.
          #if req.locale == 'us'
          #    title = title.convert('ISO-8859-1','UTF-8')
          #end
          # Cathal Mc Ginley 2008-02-18, still a problem for that ISBN!! Yep 2009-12-09!

          media = normalize(atts.get('binding'))
          media = nil if media == 'Unknown Binding'

          isbn = normalize(atts.get('isbn'))
          if isbn and Library.valid_isbn?(isbn)
            isbn = Library.canonicalise_ean(isbn)
          else
            isbn = nil # it may be an ASIN which is not an ISBN
          end
          # hack, extract year by regexp (not Y10K compatible :-)
          /([1-9][0-9]{3})/ =~ atts.get('publicationdate')
          publishing_year = $1 ? $1.to_i : nil
          book = Book.new(title,
                          atts.get_array('author').map { |x| normalize(x) },
                          isbn,
                          normalize(atts.get('manufacturer')),
                          publishing_year,
                          media)

          image_url = item.get('mediumimage/url')
          log.info { "Found at Amazon[#{request_locale}]: #{book.title}"}
          results << [ book, image_url ]
        end
        if type == SEARCH_BY_ISBN
          if results.size == 1
            return results.first
          else
            log.info { "Found multiple results for lookup: checking each" }
            query_isbn_canon = Library.canonicalise_ean(criterion)
            results.each do |rslt|
              book = rslt[0]
              book_isbn_canon = Library.canonicalise_ean(book.isbn)
              if query_isbn_canon == book_isbn_canon
                return rslt
              end
              log.debug {"rejected possible result #{book}"}
            end
            # gone through all and no ISBN match, so just return first result
            log.info {"no more results to check. Returning first result, just an approximation"}
            return results.first
          end
        else
          return results
        end
      end

      def url(book)
        begin
          isbn = Library.canonicalise_isbn(book.isbn)          
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
          url % isbn
        rescue Exception => ex
          log.warn { "Cannot create url for book #{book}; #{ex.message}" }
          nil
        end
      end

      def normalize(str)
        unless str.nil?
          str = str.squeeze(' ').strip()
        end
        str
      end

    end
  end
end
