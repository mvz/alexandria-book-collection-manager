# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "alexandria/book_providers/z3950_provider"

module Alexandria
  class BookProviders
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

      def url(_book)
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
  end
end
