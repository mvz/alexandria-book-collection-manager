# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

module Alexandria
  module Console
    def self.list_books_on_console
      collection = Alexandria::LibraryCollection.instance
      collection.reload
      libraries = collection.all_regular_libraries
      output_string = ""
      @books = libraries.flatten
      @books.each do |book|
        book_authors = book.authors.join(" & ")
        output_string += [book.title, book_authors].join(", ") + "\n"
      end
      output_string
    end
  end
end
