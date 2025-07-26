# frozen_string_literal: true

# Copyright (C) 2009 Cathal Mc Ginley
# Copyright (C) 2010 Martin Sucha
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
  # A really simple regex-based parser to grab data out of marc text records.
  class PseudoMarcParser
    BNF_FR_MAPPINGS = {
      title: ["200", "a"],
      authors: ["700", "a"],
      isbn: ["010", "a"],
      publisher: ["210", "g"],
      year: ["210", "d"],
      binding: ["225", "a"],
      notes: ["520", "a"]
    }.freeze

    USMARC_MAPPINGS = {
      title: ["245", "a", "b"],
      authors: ["100", "a"],
      isbn: ["020", "a"],
      publisher: ["490", "a"],
      year: ["260", "c"],
      binding: ["020", "a"], # listed with isbn here
      notes: ["520", "a"]
    }.freeze

    def self.get_fields(data, type, stripping, mappings = USMARC_MAPPINGS)
      field = ""
      mappings[type][1..(mappings[type].length - 1)].each do |part|
        if data.first[part]
          part_data = data.first[part].strip
          if part_data =~ stripping
            part_data = Regexp.last_match[1]
            part_data = part_data.strip
          end
          field += ": " if field != ""
          field += part_data
        end
      end
      field = nil if field == ""
      field
    end

    def self.marc_text_to_book(marc, mappings = USMARC_MAPPINGS)
      details = marc_text_to_details(marc)
      return if details.empty?

      title = nil
      title_data = details[mappings[:title][0]]
      if title_data
        title_data_all = get_fields(title_data, :title, %r{(.*)[/:]$}, mappings)
        title = title_data_all if title_data_all
      end

      authors = []
      author_data = details[mappings[:authors][0]]
      author_data&.each do |ad|
        author = ad[mappings[:authors][1]]
        if author
          author = author.strip
          author = Regexp.last_match[1] if author =~ /(.*),$/
          authors << author
        end
      end

      isbn = nil
      binding = nil
      isbn_data = details[mappings[:isbn][0]]
      if isbn_data && isbn_data.first[mappings[:isbn][1]] =~ /([-0-9xX]+)/
        isbn = Regexp.last_match[1]
      end

      binding_data = details[mappings[:binding][0]]
      if binding_data &&
          binding_data.first[mappings[:binding][1]] =~ /([a-zA-Z][a-z\s]+[a-z])/
        binding = Regexp.last_match[1]
      end

      publisher = nil
      publisher_data = details[mappings[:publisher][0]]
      publisher = publisher_data.first[mappings[:publisher][1]] if publisher_data

      year = nil
      publication_data = details[mappings[:year][0]]
      if publication_data
        year = publication_data.first[mappings[:year][1]]
        year = Regexp.last_match[1].to_i if year =~ /(\d+)/
      end

      notes = ""
      notes_data = details[mappings[:notes][0]]
      notes_data&.each do |note|
        txt = note[mappings[:notes][1]]
        notes += txt if txt
      end

      if title.nil? && isbn.nil?
        # probably didn't undertand the MARC dialect
        return nil
      end

      book = Alexandria::Book.new(title, authors, isbn,
                                  publisher, year, binding)
      book.notes = notes unless notes.empty?
      book
    end

    def self.marc_text_to_details(marc)
      details = {}
      marc&.each_line do |line|
        if line =~ /(\d+)\s*(.+)/
          code = Regexp.last_match[1]
          data = Regexp.last_match[2]

          this_line_data = {}

          d_idx = 0
          while d_idx < data.size
            d_str = data[d_idx..]
            idx = d_str =~ /\$([a-z]) ([^$]+)/
            break unless idx

            sub_code = Regexp.last_match[1]
            sub_data = Regexp.last_match[2]
            this_line_data[sub_code] = sub_data
            d_idx += idx + 2 # (2 extra to push beyond this '$a' etc.)
          end

          unless this_line_data.empty?
            details[code] = [] unless details.key?(code)
            details[code] << this_line_data
          end
        end
      end
      details
    end
  end
end
