# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "zoom"
require "alexandria/pseudo_marc_parser"
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
  end
end
