# Copyright (C) 2005 Laurent Sansonetti
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

module Alexandria
module UI
    class Icons < OSX::NSObject
        include OSX

        def self.init
            icons_dir = File.join(Alexandria::Config::DATA_DIR, "icons")
            Dir.entries(icons_dir).each do |file|
                next unless file =~ /\.png/    # skip non '.png' files
                name = File.basename(file, ".png").upcase
                const_set(name, NSImage.alloc.initWithContentsOfFile(File.join(icons_dir, file)))
            end
            
            RatingCell.setStarSetImage(Icons::STAR_SET)
            RatingCell.setStarUnsetImage(Icons::STAR_UNSET)
        end

        def self.blank?(filename)
            block = proc do |filename|
                NSImage.isBlank?(filename)
            end

            if ExecutionQueue.current != nil
                ExecutionQueue.current.sync_call(block, filename)
            else
                block.call(filename)
            end
        end
        
        def self.cover(library, book)
            filename = library.cover(book)
            image = if File.exists?(filename)
                NSImage.alloc.initWithContentsOfFile(filename)
            else
                BOOK
            end
        end
    end
end
end