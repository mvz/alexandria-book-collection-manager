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
    class ExportDialog < Gtk::FileChooserDialog
        include GetText
        extend GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        def initialize(parent, library)
            backend = `uname`.chomp == "FreeBSD" ? "neant" : "gnome-vfs"
            super(_("Export '%s'") % library.name,
                  nil,
                  Gtk::FileChooser::ACTION_SAVE,
                  backend, 
                  [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                  [Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT])
            
            self.transient_for = parent
            self.current_name = library.name
            self.signal_connect('destroy') { hide }

            theme_combo = Gtk::ComboBox.new
            theme_combo.append_text("Classic")
            theme_combo.active = 0
            theme_label = Gtk::Label.new(_("_Theme:"), true)
            theme_label.xalign = 0
            theme_label.mnemonic_widget = theme_combo 

            types_combo = Gtk::ComboBox.new
            types_combo.append_text(_("Archived ONIX XML (*.onix.tbz2)"))
            types_combo.append_text(_("Archived Tellico XML (*.bc)"))
            types_combo.append_text("XHTML (*.xhtml)")
            types_combo.active = 0
            types_combo.signal_connect('changed') do
                theme_label.visible = theme_combo.visible = 
                    types_combo.active == 2
            end
            types_combo.show

            types_label = Gtk::Label.new(_("Export for_mat:"), true)
            types_label.xalign = 0
            types_label.mnemonic_widget = types_combo 
            types_label.show
            
            # Ugly hack to add more rows in the internal Gtk::Table of the
            # widget, which is needed because we want the export type to be
            # aligned against the other widgets, and #extra_widget doesn't do
            # that... 
            internal_table = children[0].children[0].children[0].children[0].children[0]
            internal_table.resize(4, 2)
            internal_table.attach(types_label, 0, 1, 2, 3)
            internal_table.attach(types_combo, 1, 2, 2, 3)
            internal_table.attach(theme_label, 0, 1, 3, 4)
            internal_table.attach(theme_combo, 1, 2, 3, 4)

            if run == Gtk::Dialog::RESPONSE_ACCEPT
                case types_combo.active
                    when 0
                        library.export_as_onix_xml_archive(self.filename)

                    when 1
                        library.export_as_tellico_xml_archive(self.filename)

                    else
                        raise "Not yet implemented"
                end
            end
            destroy
        end
    end
end
end
