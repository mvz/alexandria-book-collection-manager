# Copyright (C) 2004-2005 Laurent Sansonetti
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
# write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

class Gdk::Pixbuf
    def tag(tag_pixbuf)
        # Computes some tweaks.
        tweak_x = tag_pixbuf.width / 3 
        tweak_y = tag_pixbuf.height / 3
        
        # Creates the destination pixbuf.
        new_pixbuf = Gdk::Pixbuf.new(Gdk::Pixbuf::COLORSPACE_RGB,
                                     true, 
                                     8, 
                                     self.width + tweak_x,
                                     self.height + tweak_y)

        # Fills with blank.
        new_pixbuf.fill!(0)

        # Copies the current pixbuf there (south-west).
        self.copy_area(0, 0, 
                       self.width, self.height,
                       new_pixbuf,
                       0, tweak_y)

        # Copies the tag pixbuf there (north-est).
        tag_pixbuf_x = self.width - (tweak_x * 2)
        new_pixbuf.composite!(tag_pixbuf, 
                              0, 0, 
                              tag_pixbuf.width + tag_pixbuf_x,
                              tag_pixbuf.height,
                              tag_pixbuf_x, 0, 
                              1, 1, 
                              Gdk::Pixbuf::INTERP_HYPER, 255)
        return new_pixbuf
    end
end

module Alexandria
module UI
    module Icons
        def self.init
            icons_dir = File.join(Alexandria::Config::DATA_DIR, "icons")
            Dir.entries(icons_dir).each do |file|
                next unless file =~ /\.png$/    # skip non '.png' files
                name = File.basename(file, ".png").upcase
                const_set(name, Gdk::Pixbuf.new(File.join(icons_dir, file)))
            end
        end

        def self.cover(library, book)
            filename = library.cover(book)
            File.exists?(filename) ? Gdk::Pixbuf.new(filename) : BOOK
        end
    end
end
end
