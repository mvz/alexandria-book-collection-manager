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

     BNF_FR_MAPPINGS = {:title => ["200", 'a'],
      :authors => ["700", 'a'],
      :isbn => ["010", 'a'],
      :publisher => ["210", 'g'],
      :year => ["210", 'd'],
      :binding => ["225", 'a'],
      :notes => ["520", 'a']
    }

    USMARC_MAPPINGS = {:title => ["245", 'a', 'b'],
      :authors => ["100", 'a'],
      :isbn => ["020", 'a'],
      :publisher => ["490", 'a'],
      :year => ["260", 'c'],
      :binding => ["020", 'a'], # listed with isbn here
      :notes => ["520", 'a']
    }

    def self.get_fields(data, type, stripping, m=USMARC_MAPPINGS)
      field = ''
      m[type][1..m[type].length-1].each do |part|
        if data.first[part]
          part_data = data.first[part].strip
          if part_data =~ stripping
            part_data = $1
            part_data = part_data.strip
          end
          if field != ''
            field += ': '
          end
          field += part_data
        end
      end
      if field == ''
        field = nil
      end
      field
    end

    def self.marc_text_to_book(marc, m=USMARC_MAPPINGS)
      details = marc_text_to_details(marc)
      unless details.empty?
        title = nil
        title_data = details[m[:title][0]]
        if title_data
          title_data_all = get_fields(title_data, :title, /(.*)[\/:]$/, m)
          if title_data_all
              title = title_data_all
          end
        end

        authors = []
        author_data = details[m[:authors][0]]
        if author_data      
          author_data.each do |ad|
            author = ad[m[:authors][1]]
            if author
              author = author.strip
              if author =~ /(.*),$/
                author = $1
              end
              authors << author
            end
          end
        end

        isbn = nil
        binding = nil
        isbn_data = details[m[:isbn][0]]
        if isbn_data
          if (isbn_data.first[m[:isbn][1]] =~ /([-0-9xX]+)/)
            isbn = $1
          end
        end

        binding_data = details[m[:binding][0]]
        if binding_data
          if (binding_data.first[m[:binding][1]] =~ /([a-zA-Z][a-z\s]+[a-z])/)
            binding = $1
          end
        end
        
        publisher = nil
        publisher_data = details[m[:publisher][0]]
        if publisher_data
          publisher = publisher_data.first[m[:publisher][1]]
        end

        year = nil
        publication_data = details[m[:year][0]]
        if publication_data
          year = publication_data.first[m[:year][1]]
          if year =~ /(\d+)/
            year = $1.to_i
          end
        end


        notes = ""
        notes_data = details[m[:notes][0]]
        if notes_data
          notes_data.each do |note|
            txt = note[m[:notes][1]]
            if txt
              notes += txt
            end
          end
        end

        if title.nil? and isbn.nil?
          # probably didn't undertand the MARC dialect
          return nil
        end

        book = Alexandria::Book.new(title, authors, isbn,
                                    publisher, year, binding)
        book.notes = notes unless notes.empty?
        book
      end
    end

    def self.marc_text_to_details(marc)
      details = {}
      marc.each_line do |line|
        if (line =~ /(\d+)\s*(.+)/)
          code = $1
          data = $2

          this_line_data = {}
          
          #puts code
          #puts data
          d_idx = 0
          while d_idx < data.size
            d_str = data[d_idx..-1]
            #puts d_str
            if (idx = d_str =~ /\$([a-z]) ([^\$]+)/)
              #puts idx
              sub_code = $1
              sub_data = $2
              this_line_data[sub_code] = sub_data
              #puts "  " + $1
              #puts "    " + $2
              #puts idx
              d_idx += idx + 2 # (2 extra to push beyond this '$a' etc.)
            else
              break
            end
          end

          unless this_line_data.empty?
            unless details.has_key?(code)
              details[code] = []
            end
            details[code] << this_line_data
          end

        end
      end
      details
    end

  end
end
