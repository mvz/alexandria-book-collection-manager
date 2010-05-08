# Copyright (C) 2010 Cathal Mc Ginley
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

# New CSV import code taken from Palatina and modified for
# Alexandria. (29 Apr 2010)

require 'csv'
require 'date'
require 'htmlentities' 
require 'tempfile'

module Alexandria

  class CSVImport 
    def initialize(header)
      @header = header
      @html = HTMLEntities.new
    end

    def index_of(header_name)
      @header.each_with_index do |h,i|
        if h == header_name
          return i
        end
      end
      return -1
    end
    
    def normalize(string)
      @html.decode(string).strip
    end

  end

  class GoodreadsCSVImport < CSVImport
    
    def initialize(header)
      super(header)
      @title = index_of("Title")
      @author = index_of("Author")
      @additional_authors = index_of("Additional Authors")
      @isbn = index_of("ISBN") 
      @publisher = index_of("Publisher")
      @publishing_year = index_of("Year Published")
      @edition = index_of("Binding")

      # optional extras
      @notes = index_of("Private Notes")
      @rating =  index_of("My Rating")
      @read_count = index_of("Read Count")
      @date_read = index_of("Date Read")
      @bookshelves = index_of("Bookshelves") # save names as tags
      @mainshelf = index_of("Exclusive Shelf")
    end

    def row_to_book(row)
      title = normalize(row[@title])
      authors = []
      authors << normalize(row[@author])
      additional = row[@additional_authors]
      additional.split(',').each do |add|
        authors << normalize(add)
      end
      isbn = row[@isbn] # TODO canonicalize_ean...
      if isbn
        isbn = Library.canonicalise_ean(isbn)
      end
      publisher = normalize(row[@publisher])
      year = row[@publishing_year].to_i
      edition = normalize(row[@edition])
      book = Alexandria::Book.new(title,
                                  authors,
                                  isbn,
                                  publisher,
                                  year,
                                  edition)
      if row[@notes]
        book.notes = normalize(row[@notes])
      end
      if row[@rating]
        book.rating = row[@rating].to_i
      end
      if row[@read_count]
        count = row[@read_count].to_i
        if count > 0
          book.redd = true
        end
      end
      if row[@date_read]
        begin
          date = Date.strptime(str, '%d/%m/%y') # e.g. "14/01/10" => 2010-01-14
          book.redd_when = date
          book.redd = true
        rescue
          # 
        end
      end
      if row[@mainshelf]
        if row[@mainshelf] == "read"
          book.redd = true
        elsif row[@mainshelf] == "to-read"
          book.redd = false
          book.tags = ["to read"]
        elsif row[@mainshelf] == "currently-reading"
          book.redd = false
          book.tags = ["currently reading"]
        end
      end
      if row[@bookshelves]
        shelves = normalize(row[@bookshelves]).split
        shelves.each do |shelf|
          tag = shelf.gsub(/-/, ' ')
          unless book.tags.include? tag
            book.tags << tag
          end
        end
      end
      puts "Goodreads loading #{book.title}" if $DEBUG
      book
    end

  end

  class LibraryThingCSVImport < CSVImport

    def initialize(header)
      super(header)
      @title = index_of("'TITLE'")
      @author = index_of("'AUTHOR (first, last)'")
      @isbn = index_of("'ISBN'")
      @publisher_info = index_of("'PUBLICATION INFO'")
      @publishing_year = index_of("'DATE'")

      # optional extras
      @notes = index_of("'COMMENTS'")
      @rating = index_of("'RATING'")
      @tags = index_of("'TAGS'")

    end

    def row_to_book(row)
      title = normalize(row[@title])
      authors = []
      authors << normalize(row[@author])
      isbn = row[@isbn]
      if isbn
        if (isbn =~ /\[([^\]]+)\]/)
          isbn = $1
        end
        isbn = Library.canonicalise_ean(isbn)
      end

      # usually "Publisher (YEAR), Binding, NUM pages"
      # sometimes "Publisher (YEAR), Edition: NUM, Binding, NUM pages"
      publisher_info = normalize(row[@publisher_info])
      publisher = publisher_info
      if (publisher_info =~ /([^\(]+)\(/)
        publisher = $1
      end
      edition = publisher_info # binding
      edition_info = publisher_info.split(',')
      if edition_info.size >= 3
        edition = publisher_info.split(',')[-2]
      end
      
      year = row[@publishing_year].to_i

      book = Alexandria::Book.new(title,
                                  authors,
                                  isbn,
                                  publisher,
                                  year,
                                  edition)
      if row[@notes]
        book.notes = normalize(row[@notes])
      end

      if row[@rating]
        book.rating = row[@rating].to_i
      end
      if row[@tags]
        tags = normalize(row[@tags]).split(',')
        tags.each do |tag|
          unless book.tags.include? tag
            book.tags << tag
          end
        end
      end

      puts "LibraryThing loading #{book.title}" if $DEBUG
      book
    end

  end

  class Library
  # LibraryThing has 15 fields (Apr 2010), Goodreads has 29
  # we shall guess that "PUBLICATION INFO" implies LibraryThing
  # and "Year Published" implies Goodreads

  def self.identify_csv_type(header)
    is_librarything = false
    is_goodreads = false
    header.each do |head|
      if head == "'PUBLICATION INFO'"
        is_librarything = true
        break
      elsif head == "Year Published"
        is_goodreads = true
        break
      end
    end
    if is_librarything
      return LibraryThingCSVImport.new(header)
    elsif is_goodreads
      return GoodreadsCSVImport.new(header)
    end
    raise "Not Recognized" unless (is_librarything || is_goodreads)
  end



end

#   def read_csv_file(csv_file)

#     reader = CSV.open(csv_file, 'r')
#     # goodreads & librarything now use csv header lines
#     header = reader.shift

#     #header.each {|h| puts h }
#     importer = identify_csv_type(header)

#     retries = 0
#     begin
#       reader.each do |row|
#         #puts row
#         bk = importer.row_to_book(row)
#         puts "\"#{bk.title}\"     by     #{bk.authors.join(', ')};     isbn : #{bk.isbn}      #{bk.publisher} | #{bk.publishing_year.inspect}   binding:#{bk.edition}"
#         if bk.notes.size > 0
#           puts "   >>> #{bk.notes}"
#         end
#       end
#     rescue
#       if retries < 1
#         retries += 1
#         puts "Retrying..."

#         # probably Goodreads' wonky ISBN fields ,,="043432432X", and such
#         # hack to fix up these files
#         data = File.read(csv_file)
#         data.gsub!(/\,\=\"/, ',"')
#         csv_fixed = Tempfile.new("#{csv_file}_fixed")
#         csv_fixed.write(data)
#         csv_fixed.close
#         reader = CSV.open(csv_fixed.path, 'r')
#         #puts csv_fixed.path
#         header = reader.shift
        
#         retry
#       end

#     end

#   end

end
