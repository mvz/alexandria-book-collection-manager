# Copyright (C) 2004 Laurent Sansonetti
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
    class ImportDialog < Gtk::FileChooserDialog
        include GetText
        extend GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        def initialize(parent, libraries, &on_accept_cb)
            backend = `uname`.chomp == "FreeBSD" ? "neant" : "gnome-vfs"
            super(_("Import a Library"),
                  nil,
                  Gtk::FileChooser::ACTION_OPEN,
                  backend, 
                  [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL])
                  
            import_button = add_button(_("Import"), 
                                       Gtk::Dialog::RESPONSE_ACCEPT)
            import_button.sensitive = false
                 
            self.transient_for = @parent = parent
            self.signal_connect('destroy') { hide }

            name_entry = Gtk::Entry.new
            
            name_entry.signal_connect('changed') do
                import_button.sensitive = !name_entry.text.strip.empty?
            end
            
            insert_filter(_("Autodetect"), '*') \
                { Library.import_autodetect(name_entry.text, self.filename) }
            insert_filter(_("Archived Tellico XML (*.bc)"), '*.bc') \
                { Library.import_as_tellico_xml_archive(name_entry.text,
                                                        self.filename) }
            insert_filter(_("ISBN List (*.txt)"), '*.txt') \
                { Library.import_as_isbn_list(name_entry.text, self.filename) }
            
            name_label = Gtk::Label.new(_("Library _name:"), true)
            name_label.xalign = 0
            name_label.mnemonic_widget = name_entry
          
            self.signal_connect('selection_changed') do
                if self.filename and File.file?(self.filename)
                    file = File.basename(self.filename, '.*')
                    name_entry.text = GLib.locale_to_utf8(file)
                else
                    name_entry.text = ""
                end
            end
            
            box = Gtk::HBox.new
            box.pack_start(name_label)
            box.pack_start(name_entry)
            box.show_all
            self.extra_widget = box
            
            while run == Gtk::Dialog::RESPONSE_ACCEPT
                if libraries.find { |x| x.name == name_entry.text.strip }
                    ErrorDialog.new(@parent, _("Couldn't import the library"),
                                    _("There is already a library named " +
                                      "'#{name_entry.text.strip}'.  " + 
                                      "Please choose a different name."))
                else
                    library = activate 
                    if library
                        on_accept_cb.call(library)
                        break
                    end
                end
            end
            destroy
        end
          
        #######
        private
        #######
        
        def insert_filter(name, *patterns, &block)
            filter = Gtk::FileFilter.new
            filter.name = name
            patterns.each { |x| filter.add_pattern(x) }
            self.add_filter(filter)
            @filters ||= { }
            @filters[filter] = block
        end
          
        def activate
            library = @filters[self.filter].call
            if library.nil?
                ErrorDialog.new(@parent, 
                                _("Couldn't import the library"),
                                _("The format of the file you provided is " +
                                  "unknown.  Please retry with another file."))
            end
            return library
        end
    end
end
end
