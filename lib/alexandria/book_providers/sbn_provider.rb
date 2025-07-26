# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "alexandria/book_providers/z3950_provider"

module Alexandria
  class BookProviders
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

      def url(_book)
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
