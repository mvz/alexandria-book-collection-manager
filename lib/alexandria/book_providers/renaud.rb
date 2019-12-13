# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

# http://en.wikipedia.org/wiki/Renaud-Bray

require "net/http"
require "cgi"

module Alexandria
  class BookProviders
    class RENAUDProvider < GenericProvider
      include GetText
      # GetText.bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")
      BASE_URI = "http://www.renaud-bray.com/"
      ACCENTUATED_CHARS = "áàâäçéèêëíìîïóòôöúùûü"

      def initialize
        super("RENAUD", "Renaud-Bray (Canada)")
      end

      def search(criterion, type)
        criterion = criterion.encode("ISO-8859-1")
        req = BASE_URI +
          "francais/menu/gabarit.asp?Rubrique=&Recherche=&Entete=Livre" \
          "&Page=Recherche_wsc.asp&OnlyAvailable=false&Tri="
        req += case type
               when SEARCH_BY_ISBN
                 "ISBN"
               when SEARCH_BY_TITLE
                 "Titre"
               when SEARCH_BY_AUTHORS
                 "Auteur"
               when SEARCH_BY_KEYWORD
                 ""
               else
                 raise InvalidSearchTypeError
               end
        req += "&Phrase="

        req += CGI.escape(criterion)
        p req if $DEBUG
        data = transport.get(URI.parse(req))
        begin
          if type == SEARCH_BY_ISBN
            to_books(data).pop
          else
            results = []
            to_books(data).each do |book|
              results << book
            end
            while /Suivant/ =~ data
              md = %r{Enteterouge\">([\d]*)</b>}.match(data)
              num = md[1].to_i + 1
              data = transport.get(URI.parse(req + "&PageActuelle=" + num.to_s))
              to_books(data).each do |book|
                results << book
              end
            end
            results
          end
        rescue StandardError
          raise NoResultsError
        end
      end

      def url(book)
        "http://www.renaud-bray.com/francais/menu/gabarit.asp?Rubrique=&Recherche=" \
          "&Entete=Livre&Page=Recherche_wsc.asp&OnlyAvailable=false&Tri=ISBN&Phrase=" + book.isbn
      end

      private

      NO_BOOKS_FOUND_REGEXP =
        %r{<strong class="Promotion">Aucun article trouv. selon les crit.res demand.s</strong>}.freeze
      HYPERLINK_SCAN_REGEXP =
        %r{"(Jeune|Lire)Hyperlien" href.*><strong>([-,'\(\)&\#;\w\s#{ACCENTUATED_CHARS}]*)</strong></a><br>}
          .freeze

      def to_books(data)
        data = CGI.unescapeHTML(data)
        data = data.encode("UTF-8")
        raise NoResultsError if NO_BOOKS_FOUND_REGEXP.match?(data)

        titles = []
        data.scan(HYPERLINK_SCAN_REGEXP).each do |md|
          titles << md[1].strip
        end
        raise if titles.empty?

        authors = []
        data.scan(%r{Nom_Auteur.*><i>([,'.&\#;\w\s#{ACCENTUATED_CHARS}]*)</i>}).each do |md|
          authors2 = []
          md[0].split("  ").each do |author|
            authors2 << author.strip
          end
          authors << authors2
        end
        raise if authors.empty?

        isbns = []
        data.scan(%r{ISBN : ?</td><td>(\d+)}).each do |md|
          isbns << md[0].strip
        end
        raise if isbns.empty?

        editions = []
        publish_years = []
        data.scan(/Parution : <br>(\d{4,}-\d{2,}-\d{2,})/).each do |md|
          editions << md[0].strip
          publish_years << md[0].strip.split(/-/)[0].to_i
        end
        raise if editions.empty? || publish_years.empty?

        publishers = []
        data.scan(%r{diteur : ([,'.&\#;\w\s#{ACCENTUATED_CHARS}]*)</span><br>}).each do |md|
          publishers << md[0].strip
        end
        raise if publishers.empty?

        book_covers = []
        data.scan(%r{(/ImagesEditeurs/[\d]*/([\dX]*-f.(jpg|gif))
                    |/francais/suggestion/images/livre/livre.gif)}x).each do |md|
          book_covers << BASE_URI + md[0].strip
        end
        raise if book_covers.empty?

        books = []
        titles.each_with_index do |title, i|
          books << [Book.new(title, authors[i], isbns[i], publishers[i], publish_years[i], editions[i]),
                    book_covers[i]]
          # print books
        end
        raise if books.empty?

        books
      end
    end
  end
end
