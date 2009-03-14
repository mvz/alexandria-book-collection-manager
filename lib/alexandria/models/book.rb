# Copyright (C) 2004-2006 Laurent Sansonetti
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

module Alexandria
  class Book
    attr_accessor :title, :authors, :isbn, :publisher, :publishing_year,
    :edition, :rating, :notes, :loaned, :loaned_since,
    :loaned_to, :saved_ident, :redd, :redd_when, :own, :want, :tags, :version, :library

    DEFAULT_RATING = 0

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
      # Need to implement bulk save function to update this
      @version = Alexandria::DATA_VERSION
    end

    def ident
      if (not @isbn.nil?) and @isbn.empty?
        @isbn = nil
      end
      @isbn or @title.hash.to_s
    end

    def loaned?
      loaned or false
    end

    def redd?
      redd or false
    end

    def want?
      want or false
    end

    def own?
      own or false
    end

    def ==(obj)
      obj.is_a?(self.class) and self.ident == obj.ident
    end
  end
end
