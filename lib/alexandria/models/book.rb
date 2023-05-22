# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

module Alexandria
  class Book
    attr_accessor :title, :authors, :isbn, :publisher, :publishing_year,
                  :edition, :notes, :loaned, :loaned_since,
                  :loaned_to, :saved_ident, :redd, :redd_when, :own, :want,
                  :tags, :version, :library

    attr_reader :rating

    DEFAULT_RATING = 0
    MAX_RATING_STARS = 5
    VALID_RATINGS = (DEFAULT_RATING..MAX_RATING_STARS)

    def initialize(title, authors, isbn, publisher, publishing_year,
                   edition)

      @title = title
      @authors = authors
      @isbn = isbn
      @publisher = publisher
      @edition = edition # actually used for binding! (i.e. paperback or hardback)
      @notes = ""
      @saved_ident = ident
      @publishing_year = publishing_year
      @redd = false
      @own = true
      @want = true
      @tags = []
      @rating = DEFAULT_RATING
      # Need to implement bulk save function to update this
      @version = Alexandria::DATA_VERSION
    end

    def ident
      @isbn = nil if !@isbn.nil? && @isbn.empty?
      @isbn || @title.hash.to_s
    end

    def rating=(rating)
      raise ArgumentError unless VALID_RATINGS.include? rating

      @rating = rating
    end

    def loaned?
      loaned || false
    end

    def redd?
      redd || false
    end

    def want?
      want || false
    end

    def own?
      own || false
    end

    def ==(other)
      other.is_a?(self.class) && (ident == other.ident)
    end

    def inspect
      "#<Alexandria::Book title: #{@title}>"
    end

    def self.from_yaml(text)
      node = YAML.parse_stream text
      doc = node.children.first
      mapping = doc.children.first
      mapping.children.each_slice(2) do |_k, v|
        v.tag = nil if v.tag == "!ruby/array:Alexandria:Library"
      end
      yaml = node.to_yaml

      # TODO: Ensure book loading passes through Book#initialize
      YAML.safe_load(yaml, permitted_classes: [Book, Time])
    end
  end
end
