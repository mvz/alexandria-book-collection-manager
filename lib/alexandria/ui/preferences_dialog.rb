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
    class PreferencesDialog < GladeBase
        def initialize(parent)
            super('preferences_dialog.glade')

            model = Gtk::ListStore.new(String)
            BookProvider.each do |provider|
                iter = model.append
                iter[0] = provider.instance.name
            end
            @treeview_providers.model = model
            column = Gtk::TreeViewColumn.new("Providers",
                                             Gtk::CellRendererText.new,
                                             :text => 0)
            @treeview_providers.append_column(column)
            @treeview_providers.selection.signal_connect('changed') do
                @button_prov_setup.sensitive = true
            end
            @button_prov_setup.sensitive = false
            @button_prov_up.sensitive =  @button_prov_down.sensitive = BookProvider.all.length > 1

            # This is an ulgy but needed hack, because Glade doesn't allow
            # Gtk::RadioButton to use a markup label.
            [ @radio_direct, @radio_proxy, @radio_gnome ].each do |button|
                button.children.first.use_markup = true
            end
        end

        def on_close
            @preferences_dialog.destroy
        end
    end
end
end
