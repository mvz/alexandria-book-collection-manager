# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

# http://de.wikipedia.org/wiki/Thalia_%28Buchhandel%29
# Thalia.de bought the Austrian book trade chain Amadeus

# New Thalia provider, taken from Palatina MetaDataSource and modified
# for Alexandria. (21 Dec 2009)

require "net/http"
require "cgi"
require "alexandria/book_providers/website_based_provider"

module Alexandria
  class BookProviders
    class ThaliaProvider < WebsiteBasedProvider
      include Logging

      SITE = "https://www.thalia.de"
      BASE_SEARCH_URL = "#{SITE}/shop/bde_bu_hg_startseite/suche/?%s=%s" # type,term

      def initialize
        super("Thalia", "Thalia (Germany)")
        # no preferences for the moment
        prefs.read
      end

      def url(book)
        create_search_uri(SEARCH_BY_ISBN, book.isbn)
      end

      def search(criterion, type)
        req = create_search_uri(type, criterion)
        log.debug { req }
        html_data = transport.get_response(URI.parse(req))
        if type == SEARCH_BY_ISBN
          parse_result_data(html_data.body, criterion)
        else
          results = parse_search_result_data(html_data.body)
          raise NoResultsError if results.empty?

          results.map { |result| get_book_from_search_result(result) }
        end
      end

      def create_search_uri(search_type, search_term)
        (search_type_code = {
          SEARCH_BY_ISBN    => "sq",
          SEARCH_BY_AUTHORS => "sa", # Autor
          SEARCH_BY_TITLE   => "st", # Titel
          SEARCH_BY_KEYWORD => "ssw" # Schlagwort
        }[search_type]) || ""
        search_type_code = CGI.escape(search_type_code)
        search_term_encoded = if search_type == SEARCH_BY_ISBN
                                # search_term_encoded = search_term.as_isbn_13
                                Library.canonicalise_isbn(search_term) # check this!
                              else
                                CGI.escape(search_term)
                              end
        format(BASE_SEARCH_URL, search_type_code, search_term_encoded)
      end

      def parse_search_result_data(html)
        doc = html_to_doc(html)
        book_search_results = []

        results_items = doc / "ul.weitere-formate li.format"

        results_items.each do |item|
          result = {}
          item_link = item % "a"
          result[:lookup_url] = "#{SITE}#{item_link['href']}"
          book_search_results << result
        end
        book_search_results
      end

      def data_from_label(node, label_text)
        label_node = node % "th[text()*='#{label_text}']"
        return "" unless label_node

        item_node = label_node.parent % "td"
        item_node.inner_text.strip
      end

      def get_book_from_search_result(result)
        log.debug { "Fetching book from #{result[:lookup_url]}" }
        html_data = transport.get_response(URI.parse(result[:lookup_url]))
        parse_result_data(html_data.body, "noisbn", recursing: true)
      end

      def parse_result_data(html, isbn, recursing: false)
        doc = html_to_doc(html)

        results_divs = doc / "ul.weitere-formate"
        unless results_divs.empty?
          if recursing
            # already recursing, avoid doing so endlessly second time
            # around *should* lead to a book description, not a result
            # list
            return
          end

          # ISBN-lookup results in multiple results
          results = parse_search_result_data(html)
          chosen = results.first # fallback!
          html_data = transport.get_response(URI.parse(chosen[:lookup_url]))
          return parse_result_data(html_data.body, isbn, recursing: true)
        end

        begin
          if (div = doc % "section#sbe-product-details")
            title = div["data-titel"]

            if (author_p = doc % "p.aim-author")
              authors = []
              author_links = author_p / :a
              author_links.each do |a|
                authors << a.inner_text.strip
              end
            end

            item_details = doc % "section.artikeldetails"
            isbns = []
            isbns << data_from_label(item_details, "EAN")
            isbns << data_from_label(item_details, "ISBN")
            isbns.reject!(&:empty?)

            year = nil
            date = data_from_label(item_details, "Erscheinungsdatum")
            year = Regexp.last_match[1].to_i if date =~ /(\d{4})/

            book_binding = data_from_label(item_details, "Einband")

            publisher = data_from_label(item_details, "Verlag")

            book = Book.new(title, authors, isbns.first,
                            publisher, year, book_binding)

            image_url = nil
            if (image = doc % "section.imagesPreview img")
              image_url = image["src"]
            end

            [book, image_url]
          end
        rescue StandardError => ex
          trace = ex.backtrace.join("\n> ")
          log.warn do
            "Failed parsing search results for Thalia " \
              "#{ex.message} #{trace}"
          end
          raise NoResultsError
        end
      end
    end
  end
end
