# -*- Mode: ruby; ruby-indent-level: 4 -*-
#
# Copyright (C) 2004-2006 Laurent Sansonetti
# Copyright (C) 2007 Cathal Mc Ginley
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

require 'alexandria/scanners/cuecat'

module Alexandria
module UI
    class AcquireDialog < GladeBase
        include GetText
        extend GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        def initialize(parent, selected_library=nil, &block)
            super('acquire_dialog.glade')
            @acquire_dialog.transient_for = @parent = parent
            @block = block

            libraries = Libraries.instance.all_regular_libraries
            if selected_library.is_a?(SmartLibrary)
                selected_library = libraries.first
            end
            @combo_libraries.populate_with_libraries(libraries,
                                                     selected_library) 

            @add_button.sensitive = false 
            setup_scanner_area
            init_treeview
        end

        def on_add
        end

        def on_cancel
            @acquire_dialog.destroy
        end

        def on_help
        end

        def read_barcode_scan
            puts "reading CueCat data #{@scanner_buffer}"
            buf = @scanner_buffer
            @scanner_buffer = ""
            barcode_text = @scanner.decode(buf)
            puts "got barcode text #{barcode_text}"
            begin
                isbn = Library.canonicalise_isbn(barcode_text)
                # TODO :: use an AppFacade
                # isbn =  LookupBook.get_isbn(barcode_text)
            rescue
                puts "barcode invalid somehow #{isbn}"
            end
            if isbn
                puts "<<< #{isbn} >>>"
                # TODO :: sound
                # play_sound("gnometris/turn")
                
                #t = Thread.new(isbn) do |isbn|
                @barcodes_treeview.model.freeze_notify do
                    iter = @barcodes_treeview.model.append
                    iter[0] = isbn
                    iter[1] = "<<Title>>"
                end
                #end
            else
                puts "was not an ISBN barcode"
                # TODO :: sound
                # play_sound("question")
            end 
        end

        private
        
        def setup_scanner_area
            @scanner_buffer = ""
            @scanner = Alexandria::Scanners::CueCat.new # HACK :: use Registry

            # attach signals
            @scan_area.signal_connect("button-press-event") do |widget, event|
                @scan_area.grab_focus
            end
            @scan_area.signal_connect("focus-in-event") do |widget, event|
                @barcode_label.label = _("_Barcode Scanner Ready")
                @scanner_buffer = ""
            end
            @scan_area.signal_connect("focus-out-event") do |widget, event|
                @barcode_label.label = _("Click Here To Scan _Barcodes")
                @scanner_buffer = ""
            end

            @scan_area.signal_connect("key-press-event") do |button, event|
                #puts event.keyval
                if event.keyval < 255
                    if @scanner_buffer.empty?
                        # this is our first character, notify user
                        puts "Scanning... "                     
                        # TODO :: sound
                        # play_sound("iagno/flip-piece")
                    end
                    @scanner_buffer << event.keyval.chr
                    
                    # or get event.keyval == 65293 meaning Enter key
                    if @scanner.match? @scanner_buffer
                        read_barcode_scan
                    end
                end
            end


            # TODO :: sound
            # Gnome::Sound.init("localhost")

        end

        def init_treeview
            puts 'initializing treeview...'
            liststore = Gtk::ListStore.new(String, String)

            @barcodes_treeview.model = liststore

            text_renderer = Gtk::CellRendererText.new
            text_renderer.editable = false

            # Add column using our renderer
            col = Gtk::TreeViewColumn.new("ISBN", text_renderer, :text => 0)
            @barcodes_treeview.append_column(col)

            # Add column using the second renderer
            col = Gtk::TreeViewColumn.new("Title", text_renderer, :text => 1)
            @barcodes_treeview.append_column(col)
        end
        
        #def play_sound(filename)
        #    dir = "/usr/share/sounds"        
        #    Gnome::Sound.play("#{dir}/#{filename}.wav")
        #end

    end
end
end
