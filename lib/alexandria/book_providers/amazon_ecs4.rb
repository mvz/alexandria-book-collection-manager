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

module Alexandria
  class BookProviders
    class AmazonECSProvider < GenericProvider
      include Logging
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

      #CACHE_DIR = File.join(Alexandria::Library::DIR, '.amazon_cache')

      LOCALES = ['ca','de','fr','jp','uk','us']

      def initialize
        super("AmazonECS", "Amazon ECS")
        prefs.add("locale", _("Locale"), "us", AmazonECSProvider::LOCALES)
        prefs.add("dev_token", _("Development token"),
                  "0J356Z09CN88KB743582")
        #prefs.add("associate", _("Associate ID"), "calibanorg-20", nil,
        #          false)

        # Backward compatibility hack - the previous developer token has
        # been revoked.
        prefs.read
        token = prefs.variable_named("dev_token")
        if token and token.value.size != 20
          token.new_value = "0J356Z09CN88KB743582"
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

        Amazon::Ecs.options = {:aWS_access_key_id => prefs["dev_token"] }
        ##req.cache = Amazon::Search::Cache.new(CACHE_DIR)
        locales = AmazonECSProvider::LOCALES.dup
        locales.delete prefs["locale"]
        locales.unshift prefs["locale"]
        locales.reverse!

        begin
          request_locale = locales.pop.intern
          products = []
          case type
          when SEARCH_BY_ISBN
            criterion = Library.canonicalise_isbn(criterion)
            log.debug { "Amazon ECS search #{request_locale} for #{criterion}" }
            # This isn't ideal : I'd like to do an ISBN/EAN-specific search
            res = Amazon::Ecs.item_search(criterion, {:response_group =>'ItemAttributes,Images', :country => request_locale})
            res.items.each do |item|
              products << item
            end
            ##req.asin_search(criterion) do |product|

            # shouldn't happen
            raise TooManyResultsError if products.length > 1

          when SEARCH_BY_TITLE
            log.debug { "searching by title..." }
            res = Amazon::Ecs.item_search(criterion, {:response_group =>'ItemAttributes,Images', :country => request_locale})

            res.items.each do |item|
              if /#{criterion}/i.match(item.get('itemattributes/title'))
                products << item
              end
            end
            ##req.keyword_search(criterion) do |product|

          when SEARCH_BY_AUTHORS
            log.debug { "searching by author..." }
            criterion = "author:#{criterion}"
            res = Amazon::Ecs.item_search(criterion, {:response_group =>'ItemAttributes,Images', :country => request_locale, :type => 'Power'})
            res.items.each do |item|
              products << item
            end
            ##req.author_search(criterion) do |product|

          when SEARCH_BY_KEYWORD
            log.debug { "searching by keyword..." }
            res = Amazon::Ecs.item_search(criterion, {:response_group =>'ItemAttributes,Images', :country => request_locale})

            res.items.each do |item|
              products << item
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
        products.each do |item|
          next unless item.get('itemattributes/productgroup') == 'Book'
          atts = item.search_and_convert('itemattributes')
          title = atts.get('title').squeeze(' ')

          # Work around Amazon US encoding bug. Amazon US apparently
          # interprets UTF-8 titles as ISO-8859 titles and then converts
          # the garbled titles to UTF-8. This tries to convert back into
          # valid UTF-8. It does not always work - see isbn 2259196098
          # (from the mailing list) for an example.
          #if req.locale == 'us'
          #    title = title.convert('ISO-8859-1','UTF-8')
          #end
          # Cathal Mc Ginley 2008-02-18, still a problem for that ISBN!!

          media = atts.get('binding').squeeze(' ')
          media = nil if media == 'Unknown Binding'

          isbn = atts.get('isbn').squeeze(' ')
          if Library.valid_isbn?(isbn)
            isbn = Library.canonicalise_ean(isbn)
          else
            isbn = nil # it may be an ASIN which is not an ISBN
          end
          # hack, extract year by regexp (not Y10K compatible :-)
          /([1-9][0-9]{3})/ =~ atts.get('publicationdate')
          publishing_year = $1 ? $1.to_i : nil
          book = Book.new(title,
                          (atts.get_array('author').map { |x| x.squeeze(' ') } \
                         rescue [  ]),
                          isbn,
                          (atts.get('manufacturer').squeeze(' ') \
                         rescue nil),
                          publishing_year,
                          media)

          image_url = item.get('mediumimage/url')
          log.info { "Found with AmazonECS: #{book.title}"}
          results << [ book, image_url ]
        end
        type == SEARCH_BY_ISBN ? results.first : results
      end

      def url(book)
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
        url % Library.canonicalise_isbn(book.isbn)
      end
    end
  end
end
