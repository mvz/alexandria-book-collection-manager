# Copyright (C) 2008 Joseph Method
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
  def self.list_books_on_console(title = true, authors=true)
    libraries_simpleton = Alexandria::Libraries.instance
    libraries_simpleton.reload
    libraries = Alexandria::Library.loadall
    output_string = ""
    @books = libraries.flatten
    @books.each do |book|
      book_authors = book.authors.join(" & ") if authors
      output_string += [book.title, book_authors].join(", ") + "\n"
    end
    output_string
  end
end
