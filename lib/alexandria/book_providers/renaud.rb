# Copyright (C) 2005-2006-2006 Mathieu Leduc-Hamel
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

# http://en.wikipedia.org/wiki/Renaud-Bray

require 'net/http'
require 'cgi'

module Alexandria
  class BookProviders
    class RENAUDProvider < GenericProvider
      include GetText
      #GetText.bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")
      BASE_URI = "http://www.renaud-bray.com/"
      ACCENTUATED_CHARS = "áàâäçéèêëíìîïóòôöúùûü"

      def initialize
        super("RENAUD", "Renaud-Bray (Canada)")
      end

      def search(criterion, type)
        criterion = criterion.convert("ISO-8859-1", "UTF-8")
        req = BASE_URI + "francais/menu/gabarit.asp?Rubrique=&Recherche=&Entete=Livre&Page=Recherche_wsc.asp&OnlyAvailable=false&Tri="
        #        req = BASE_URI + "francais/menu/gabarit.asp?Rubrique=&Recherche=&Entete=Livre&Page=Recherche_section_wsc.asp&OnlyAvailable=false&Tri="
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
            return to_books(data).pop()
          else
            results = []
            to_books(data).each{|book|
              results << book
            }
            while /Suivant/.match(data)
              md = /Enteterouge\">([\d]*)<\/b>/.match(data)
              num = md[1].to_i+1
              data = transport.get(URI.parse(req+"&PageActuelle="+num.to_s))
              to_books(data).each{|book|
                results << book
              }
            end
            return results
          end
        rescue
          raise NoResultsError
        end
      end

      def url(book)
        #        "http://www.renaud-bray.com/francais/menu/gabarit.asp?Rubrique=&Recherche=&Entete=Livre&Page=Recherche_section_wsc.asp&OnlyAvailable=false&Tri=ISBN&Phrase=" + book.isbn
        "http://www.renaud-bray.com/francais/menu/gabarit.asp?Rubrique=&Recherche=&Entete=Livre&Page=Recherche_wsc.asp&OnlyAvailable=false&Tri=ISBN&Phrase=" + book.isbn
      end

      #######
      private
      #######

      def to_books(data)
        data = CGI::unescapeHTML(data)
        data = data.convert("UTF-8", "ISO-8859-1")
        raise NoResultsError if /<strong class="Promotion">Aucun article trouv. selon les crit.res demand.s<\/strong>/.match(data) != nil

        titles = []
        data.scan(/"(Jeune|Lire)Hyperlien" href.*><strong>([-,'\(\)&\#;\w\s#{ACCENTUATED_CHARS}]*)<\/strong><\/a><br>/).each{|md|
          titles << md[1].strip
        }
        raise if titles.empty?
        authors = []
        data.scan(/Nom_Auteur.*><i>([,'.&\#;\w\s#{ACCENTUATED_CHARS}]*)<\/i>/).each{|md|
          authors2 = []
          for author in md[0].split('  ')
            authors2 << author.strip
          end
          authors << authors2
        }
        raise if authors.empty?
        isbns = []
        data.scan(/ISBN : ?<\/td><td>(\d+)/).each{|md|
          isbns << md[0].strip
        }
        raise if isbns.empty?
        editions = []
        publish_years = []
        data.scan(/Parution : <br>(\d{4,}-\d{2,}-\d{2,})/).each{|md|
          editions << md[0].strip
          publish_years << md[0].strip.split(/-/)[0].to_i
        }
        raise if editions.empty? or publish_years.empty?
        publishers = []
        data.scan(/diteur : ([,'.&\#;\w\s#{ACCENTUATED_CHARS}]*)<\/span><br>/).each{|md|
          publishers << md[0].strip
        }
        raise if publishers.empty?
        book_covers = []
        data.scan(/(\/ImagesEditeurs\/[\d]*\/([\dX]*-f.(jpg|gif))|\/francais\/suggestion\/images\/livre\/livre.gif)/).each{|md|
          book_covers << BASE_URI + md[0].strip
        }
        raise if book_covers.empty?

        books = []
        titles.each_with_index{|title, i|
          books << [Book.new(title, authors[i], isbns[i], publishers[i], publish_years[i], editions[i]),
                    book_covers[i]]
          #print books
        }
        raise if books.empty?

        return books
      end

    end
  end
end
