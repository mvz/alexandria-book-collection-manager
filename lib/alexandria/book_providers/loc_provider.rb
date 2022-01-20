# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "alexandria/book_providers/z3950_provider"

module Alexandria
  class BookProviders
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
  end
end
