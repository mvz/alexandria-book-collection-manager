# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

# New Proxis provider, taken from Palatina MetaDataSource and modified
# for Alexandria. (20 Dec 2009)

require "cgi"
require "alexandria/book_providers/web"

module Alexandria
  class BookProviders
    class ProxisProvider < WebsiteBasedProvider
      # include GetText
      include Alexandria::Logging
      # GetText.bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")

      # Proxis essentially has three book databases, NL, FR and EN.
      # Currently, this provider only searches the NL database, since
      # it adds most to Alexandria (Amazon already has French and
      # English titles).

      SITE = "http://www.proxis.nl"
      BASE_SEARCH_URL = "#{SITE}/NLNL/Search/IndexGSA.aspx?search=%s" \
        "&shop=100001NL&SelRubricLevel1Id=100001NL"
      ISBN_REDIRECT_BASE_URL = "#{SITE}/NLNL/Search/Index.aspx?search=%s" \
        "&shop=100001NL&SelRubricLevel1Id=100001NL"

      def initialize
        super("Proxis", "Proxis (Belgium)")
        # prefs.add("lang", _("Language"), "fr",
        #          LANGUAGES.keys)
        prefs.read
      end

      def search(criterion, type)
        req = create_search_uri(type, criterion)
        puts req if $DEBUG
        html_data = transport.get_response(URI.parse(req))

        results = parse_search_result_data(html_data.body)
        raise NoResultsError if results.empty?

        if type == SEARCH_BY_ISBN
          get_book_from_search_result(results.first)
        else
          results.map { |result| get_book_from_search_result(result) }
        end
      end

      def create_search_uri(search_type, search_term)
        if search_type == SEARCH_BY_ISBN
          BASE_SEARCH_URL % Library.canonicalise_ean(search_term)
        else
          BASE_SEARCH_URL % CGI.escape(search_term)
        end
      end

      def get_book_from_search_result(result)
        log.debug { "Fetching book from #{result[:lookup_url]}" }
        html_data = transport.get_response(URI.parse(result[:lookup_url]))
        parse_result_data(html_data.body)
      end

      def url(book)
        if book.isbn.nil? || book.isbn.empty?
          ISBN_REDIRECT_BASE_URL % Library.canonicalise_ean(book.isbn)
        end
      end

      ## from Palatina
      def text_of(node)
        if node.nil?
          nil
        elsif node.text?
          node.to_html
        elsif node.elem?
          if node.children.nil?
            nil
          else
            node_text = node.children.map { |n| text_of(n) }.join
            node_text.strip.squeeze(" ")
          end
        end
      end

      def parse_search_result_data(html)
        doc = html_to_doc(html)
        book_search_results = []
        items = doc.search("table.searchResult tr")
        items.each do |item|
          result = {}
          title_link = item % "h5 a"
          if title_link
            result[:title] = text_of(title_link)
            result[:lookup_url] = title_link["href"]
            unless /^http/.match?(result[:lookup_url])
              result[:lookup_url] = "#{SITE}#{result[:lookup_url]}"
            end
          end
          book_search_results << result
        end
        # require 'pp'
        # pp book_search_results
        # raise :Ruckus
        book_search_results
      end

      def data_for_header(th)
        tr = th.parent
        td = tr.at("td")
        text_of(td) if td
      end

      def parse_result_data(html)
        doc = html_to_doc(html)
        book_data = {}
        book_data[:authors] = []
        # TITLE
        if (title_header = doc.search("div.detailBlock h3"))
          header_spans = title_header.first.search("span")
          title = text_of(header_spans.first)
          title = Regexp.last_match[1].strip if title =~ /(.+)-$/
          book_data[:title] = title
        end

        info_headers = doc.search("table.productInfoTable th")

        isbns = []
        unless info_headers.empty?
          info_headers.each do |th|
            isbns << data_for_header(th) if /(ISBN|EAN)/.match?(th.inner_text)
          end
          book_data[:isbn] = Library.canonicalise_ean(isbns.first)
        end

        # book = Book.new(title, ISBN.get(isbns.first))

        unless info_headers.empty?
          info_headers.each do |th|
            header_text = th.inner_text
            if /Type/.match?(header_text)
              book_data[:binding] = data_for_header(th)
            elsif /Verschijningsdatum/.match?(header_text)
              date = data_for_header(th)
              date =~ %r{/([\d]{4})}
              book_data[:publish_year] = Regexp.last_match[1].to_i
            elsif /Auteur/.match?(header_text)
              book_data[:authors] << data_for_header(th)
            elsif /Uitgever/.match?(header_text)
              book_data[:publisher] = data_for_header(th)
            end
          end
        end

        image_url = nil
        if (cover_img = doc.at("img[@id$='imgProduct']"))
          image_url = if /^http/.match?(cover_img["src"])
                        cover_img["src"]
                      else
                        "#{SITE}/#{cover_img['src']}" # TODO: use html <base>
                      end
          image_url = nil if /ProductNoCover/.match?(image_url)
        end

        book = Book.new(book_data[:title], book_data[:authors],
                        book_data[:isbn], book_data[:publisher],
                        book_data[:publish_year], book_data[:binding])
        [book, image_url]
      end
    end
  end
end
