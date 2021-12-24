# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

## $Z3950_DEBUG = $DEBUG

require "zoom"
require "alexandria/book_providers/pseudomarc"
require "marc"

module Alexandria
  class BookProviders
    class Z3950Provider < AbstractProvider
      include Logging
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

      def initialize(name = "Z3950", fullname = "Z39.50")
        super
        prefs.add("hostname", _("Hostname"), "")
        prefs.add("port", _("Port"), 7090)
        prefs.add("database", _("Database"), "")
        prefs.add("record_syntax", _("Record syntax"), "USMARC",
                  ["USMARC", "UNIMARC", "SUTRS"])
        prefs.add("username", _("Username"), "", nil, false)
        prefs.add("password", _("Password"), "", nil, false)
        prefs.add("charset", _("Charset encoding"), "ISO-8859-1")

        # HACK : piggybacking support
        prefs.add("piggyback", "Piggyback", true, [true, false])
        prefs.read
      end

      def search(criterion, type)
        prefs.read
        criterion = criterion.encode(prefs["charset"])

        isbn = type == SEARCH_BY_ISBN ? criterion : nil
        criterion = canonicalise_criterion(criterion, type)
        conn_count = request_count(type)
        resultset = search_records(criterion, type, conn_count)
        log.debug { "total #{resultset.length}" }

        results = books_from_resultset(resultset, isbn)
        raise NoResultsError if results.empty?

        type == SEARCH_BY_ISBN ? results.first : results
      end

      def url(_book)
        nil
      end

      def books_from_resultset(resultset, isbn)
        case prefs["record_syntax"]
        when /MARC$/
          books_from_marc(resultset, isbn)
        when "SUTRS"
          books_from_sutrs(resultset)
        else
          raise NoResultsError
        end
      end

      private

      def request_count(type)
        type == SEARCH_BY_ISBN ? 1 : 10 # results to retrieve
      end

      def canonicalise_criterion(criterion, type)
        criterion = Library.canonicalise_isbn(criterion) if type == SEARCH_BY_ISBN
        criterion
      end

      def books_from_sutrs(_resultset)
        # SUTRS needs to be decoded separately, because each Z39.50 server has a
        # different one.
        raise NoResultsError
      end

      def marc_to_book(marc_txt, isbn)
        begin
          marc = MARC::Record.new_from_marc(marc_txt, forgiving: true)
        rescue StandardError => ex
          log.error { ex.message }
          log.error { ex.backtrace.join("> \n") }
          begin
            marc = MARC::Record.new(marc_txt)
          rescue StandardError => ex
            log.error { ex.message }
            log.error { ex.backtrace.join("> \n") }
            raise ex
          end
        end

        log.debug do
          msg = "Parsing MARC"
          msg += "\n title: #{marc.title}"
          msg += "\n authors: #{marc.authors.join(', ')}"
          msg += "\n isbn: #{marc.isbn}, #{isbn}"
          msg += "\n publisher: #{marc.publisher}"
          msg += "\n publish year: #{marc.publish_year}" if marc.respond_to?(:publish_year)
          msg += "\n edition: #{marc.edition}"
          msg
        end

        return if marc.title.nil? # or marc.authors.empty?

        isbn ||= marc.isbn
        isbn = Library.canonicalise_ean(isbn)

        Book.new(marc.title, marc.authors,
                 isbn,
                 (marc.publisher || ""),
                 marc.respond_to?(:publish_year) ? marc.publish_year.to_i : nil,
                 (marc.edition || ""))
      end

      def books_from_marc(resultset, isbn)
        results = []
        resultset[0..9].each do |record|
          marc_txt = record.render(prefs["charset"], "UTF-8")
          log.debug { marc_txt }
          File.binwrite(",marc.txt", marc_txt) if $DEBUG
          book = nil
          begin
            mappings = Alexandria::PseudoMarcParser::USMARC_MAPPINGS
            if prefs["hostname"] == "z3950.bnf.fr"
              mappings = Alexandria::PseudoMarcParser::BNF_FR_MAPPINGS
            end
            # try pseudo-marc parser first (it seems to have more luck)
            book = Alexandria::PseudoMarcParser.marc_text_to_book(marc_txt,
                                                                  mappings)
            if book.nil?
              # failing that, try the genuine MARC parser
              book = marc_to_book(marc_txt, isbn)
            end
          rescue StandardError => ex
            log.warn { ex }
            log.warn { ex.backtrace }
          end

          results << [book] unless book.nil?
        end
        results
      end

      def marc?
        prefs["record_syntax"].end_with?("MARC")
      end

      def search_records(criterion, type, conn_count)
        options = {}
        unless prefs["username"].empty? || prefs["password"].empty?
          options["user"] = prefs["username"]
          options["password"] = prefs["password"]
        end
        hostname = prefs["hostname"]
        port = prefs["port"].to_i
        log.debug { "hostname #{hostname} port #{port} options #{options}" }
        conn = ZOOM::Connection.new(options).connect(hostname, port)
        conn.database_name = prefs["database"]

        conn.preferred_record_syntax = prefs["record_syntax"]
        conn.element_set_name = "F"
        conn.count = conn_count
        attr = case type
               when SEARCH_BY_ISBN     then [7]
               when SEARCH_BY_TITLE    then [4]
               when SEARCH_BY_AUTHORS  then [1, 1003]
               when SEARCH_BY_KEYWORD  then [1016]
               end
        pqf = ""
        attr.each { |att| pqf += "@attr 1=#{att} " }
        pqf += '"' + criterion.upcase + '"'
        log.debug { "pqf is #{pqf}, syntax #{prefs['record_syntax']}" }

        begin
          if prefs.variable_named("piggyback") && !prefs["piggyback"]
            log.debug { "setting conn.piggyback to false" }
            conn.piggyback = false
          end
          conn.search(pqf)
        rescue StandardError => ex
          if /1005/.match?(ex.message) &&
              prefs.variable_named("piggyback") && prefs["piggyback"]
            log.error { "Z39.50 search failed:: #{ex.message}" }
            log.info { "Turning off piggybacking for this provider" }
            prefs.variable_named("piggyback").new_value = false
            retry
          end

          raise ex
        end
      end
    end

    class LOCProvider < Z3950Provider
      # http://en.wikipedia.org/wiki/Library_of_Congress
      unabstract

      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

      def initialize
        super("LOC", _("Library of Congress (Usa)"))
        prefs.variable_named("hostname").default_value = "z3950.loc.gov"
        prefs.variable_named("port").default_value = 7090
        prefs.variable_named("database").default_value = "Voyager"
        prefs.variable_named("record_syntax").default_value = "USMARC"
        prefs.variable_named("charset").default_value = "ISO-8859-1"
        prefs.read
      end

      def url(book)
        isbn = Library.canonicalise_isbn(book.isbn)
        "http://catalog.loc.gov/cgi-bin/Pwebrecon.cgi?" \
          "DB=local&CNT=25+records+per+page&CMD=isbn+#{isbn}"
      rescue StandardError => ex
        log.warn { "Cannot create url for book #{book}; #{ex.message}" }
        nil
      end
    end

    class BLProvider < Z3950Provider
      # http://en.wikipedia.org/wiki/Copac
      # http://en.wikipedia.org/wiki/British_Library
      # http://www.bl.uk/catalogues/z3950fullaccess.html
      # http://www.bl.uk/catalogues/z3950copacaccess.html
      #
      # FIXME: switch from BL to Copac, which incudes the BL itself and many more
      # libraries: http://copac.ac.uk/libraries/
      #
      # Details: http://copac.ac.uk/interfaces/z39.50/
      # The SUTRS format used by Copac is different from the one used by BL
      unabstract

      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

      def initialize
        super("BL", _("British Library"))
        prefs.variable_named("hostname").default_value = "z3950cat.bl.uk"
        prefs.variable_named("port").default_value = 9909
        prefs.variable_named("database").default_value = "BLAC"
        prefs.variable_named("record_syntax").default_value = "SUTRS"
        prefs.variable_named("charset").default_value = "ISO-8859-1"
        prefs.read
      end

      def url(book)
        "http://copac.ac.uk/openurl?isbn=" + Library.canonicalise_isbn(book.isbn)
      rescue StandardError => ex
        log.warn { "Cannot create url for book #{book}; #{ex.message}" }
        nil
      end

      private

      def books_from_sutrs(resultset)
        results = []
        resultset[0..9].each do |record|
          text = record.render(prefs["charset"], "UTF-8")
          # File.open(',bl.marc', 'wb') {|f| f.write(text) }
          log.debug { text }

          title = isbn = publisher = publish_year = edition = nil
          authors = []

          text.split("\n").each do |line|
            if (md = /^Title:\s+(.*)$/.match(line))
              title = md[1].sub(/\.$/, "").squeeze(" ")
            elsif (md = /^(?:Added Person|ME-Personal) Name:\s+(.*),[^,]+$/.match(line))
              authors << md[1]
            elsif (md = /^ISBN:\s+([\dXx]+)/.match(line))
              isbn = Library.canonicalise_ean(md[1])
            elsif (md = /^Imprint:.+:\s*(.+),/.match(line))
              publisher = md[1]
            end
          end

          log.debug do
            msg = "Parsing SUTRS"
            msg += "\n title: #{title}"
            msg += "\n authors: #{authors.join(' and ')}"
            msg += "\n isbn: #{isbn}"
            msg += "\n publisher: #{publisher}"
            msg += "\n edition: #{edition}"
            msg
          end

          if title # and !authors.empty?
            book = Book.new(title, authors, isbn, (publisher || nil),
                            (publish_year || nil), (edition || nil))
            results << [book]
          end
        end
        results
      end
    end

    class SBNProvider < Z3950Provider
      # http://sbnonline.sbn.it/
      # http://it.wikipedia.org/wiki/ICCU
      unabstract

      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

      def initialize
        super("SBN", "Servizio Bibliotecario Nazionale (Italy)")
        prefs.variable_named("hostname").default_value = "opac.sbn.it"
        prefs.variable_named("port").default_value = 3950
        prefs.variable_named("database").default_value = "nopac"
        # supported 'USMARC', 'UNIMARC' , 'SUTRS'
        prefs.variable_named("record_syntax").default_value = "USMARC"
        prefs.variable_named("charset").default_value = "ISO-8859-1"
        prefs.read
      end

      def url(book)
        "http://sbnonline.sbn.it/cgi-bin/zgw/BRIEF.pl?displayquery=" \
        "%253CB%253E%253Cfont%2520color%253D%2523000064%253E" \
        "Codice%2520ISBN%253C%2FB%253E%253C%2Ffont%253E%2520" \
        "contiene%2520%2522%2520%253CFONT%2520COLOR%253Dred%253E" +
          canonicalise_isbn_with_dashes(book.isbn) +
          "%253C%2FFONT%253E%2522&session=&zurl=opac" \
          "&zquery=%281%3D7+4%3D2+2%3D3+5%3D100+6%3D1+3%3D3+%22" +
          canonicalise_isbn_with_dashes(book.isbn) +
          "%22%29&language=it&maxentries=10&target=0&position=1"
      rescue StandardError => ex
        log.warn { "Cannot create url for book #{book}; #{ex.message}" }
        nil
      end

      private

      def canonicalise_criterion(criterion, _type)
        canonicalise_isbn_with_dashes(criterion)
      end

      def request_count(_type)
        0
      end

      def canonicalise_isbn_with_dashes(isbn)
        # The reference for the position of the dashes is
        # http://www.isbn-international.org/converter/ranges.htm

        isbn = Alexandria::Library.canonicalise_isbn(isbn)

        if isbn[0..1] == "88"
          # Italian speaking area
          if isbn > "8895000" && (isbn <= "8899999996")
            isbn[0..1] + "-" + isbn[2..6] + "-" + isbn[7..8] + "-" + isbn[9..9]
          elsif isbn > "88900000"
            isbn[0..1] + "-" + isbn[2..7] + "-" + isbn[8..8] + "-" + isbn[9..9]
          elsif isbn > "8885000"
            isbn[0..1] + "-" + isbn[2..6] + "-" + isbn[7..8] + "-" + isbn[9..9]
          elsif isbn > "886000"
            isbn[0..1] + "-" + isbn[2..5] + "-" + isbn[6..8] + "-" + isbn[9..9]
          elsif isbn > "88200"
            isbn[0..1] + "-" + isbn[2..4] + "-" + isbn[5..8] + "-" + isbn[9..9]
          elsif isbn > "8800"
            isbn[0..1] + "-" + isbn[2..3] + "-" + isbn[4..8] + "-" + isbn[9..9]
          else
            raise _("Invalid ISBN")
          end

        else
          isbn
        end
      end
      #
      # Remarks about SBN
      #
      # This provider requires that value of conn.count is 0.
      # It's a Yaz option "Number of records to be retrieved".
      # This provider requires to specify the value of conn.element_set_name = 'F'.
      # It's a Yaz option "Element-Set name of records".
      # See http://www.indexdata.dk/yaz/doc/zoom.resultsets.tkl
      #
      # Dashes:
      # this database requires that Italian books are searched with dashes :(
      # However, they have also books with dashes in wrong positions, for
      # instance 88-061-4934-2
      #
      # References:
      # http://opac.internetculturale.it/cgi-bin/main.cgi?type=field
      # http://www.internetculturale.it/
      # http://sbnonline.sbn.it/zgw/homeit.html
      # http://www.iccu.sbn.it/genera.jsp?id=124
      # with link at http://www.iccu.sbn.it/upload/documenti/cartecsbn.pdf
      # http://www.loc.gov/cgi-bin/zgstart?ACTION=INIT&FORM_HOST_PORT=/prod/www/data/z3950/iccu.html,opac.sbn.it,2100
      # http://gwz.cilea.it/cgi-bin/reportOpac.cgi
      #
    end
  end
end
