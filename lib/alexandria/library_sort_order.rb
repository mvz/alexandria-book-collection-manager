# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

module Alexandria
  class LibrarySortOrder
    include Logging

    def initialize(book_attribute, ascending = true)
      @book_attribute = book_attribute
      @ascending = ascending
    end

    def sort(library)
      sorted = library.sort_by do |book|
        book.send(@book_attribute)
      end
      sorted.reverse! unless @ascending
      sorted
    rescue StandardError => ex
      log.warn { "Could not sort library by #{@book_attribute.inspect}: #{ex.message}" }
      library
    end

    def to_s
      "#{@book_attribute} #{@ascending ? '(ascending)' : '(descending)'}"
    end

    class Unsorted < LibrarySortOrder
      def initialize
        super(nil, nil)
      end

      def sort(library)
        library
      end

      def to_s
        "default order"
      end
    end
  end
end
