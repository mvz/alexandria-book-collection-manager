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
    class ProviderPreferencesDialog < Gtk::Dialog
        def initialize(parent, provider)
            super("Preferences for #{provider.name}",
                  parent,
                  Gtk::Dialog::MODAL,
                  [ Gtk::Stock::CLOSE, Gtk::Dialog::RESPONSE_CLOSE ])
            self.has_separator = false
            self.resizable = false
            self.vbox.border_width = 12
            
            hbox = Gtk::HBox.new(false, 12)
            hbox.border_width = 6
            self.vbox.pack_start(hbox)

            image = Gtk::Image.new(Gtk::Stock::PROPERTIES,
                                   Gtk::IconSize::DIALOG)
            image.set_alignment(0.5, 0)
            hbox.pack_start(image)

            table = Gtk::Table.new(provider.prefs.length, 2)
            table.row_spacings = 6 
            table.column_spacings = 12 
            i = 0
            provider.prefs.each do |variable|
                label = Gtk::Label.new("_" + variable.description + ":")
                label.use_underline = true
                label.xalign = 0
                table.attach_defaults(label, 0, 1, i, i + 1)
               
                unless variable.possible_values.nil?
                    menu = Gtk::Menu.new
                    variable.possible_values.each do |value|
                        menu.append(Gtk::MenuItem.new(value.to_s))
                    end
                    entry = Gtk::OptionMenu.new
                    entry.menu = menu
                    entry.history = variable.possible_values.index(variable.value) 
                else
                    entry = Gtk::Entry.new
                    entry.text = variable.value.to_s
                end
                label.mnemonic_widget = entry

                table.attach_defaults(entry, 1, 2, i, i + 1)
                i += 1
            end

            hbox.pack_start(table)
        end
    end

    class PreferencesDialog < GladeBase
        def initialize(parent)
            super('preferences_dialog.glade')
            @preferences_dialog.transient_for = parent

            model = Gtk::ListStore.new(String)
            BookProviders.each { |x| model.append.set_value(0, x.name) }
            @treeview_providers.model = model
            column = Gtk::TreeViewColumn.new("Providers",
                                             Gtk::CellRendererText.new,
                                             :text => 0)
            @treeview_providers.append_column(column)
            @treeview_providers.selection.signal_connect('changed') do
                @button_prov_setup.sensitive = true
            end
            @button_prov_setup.sensitive = false
            @button_prov_up.sensitive =  @button_prov_down.sensitive = BookProviders.length > 1
        end

        def on_setup
            iter = @treeview_providers.selection.selected
            provider = BookProviders.find { |x| x.name == iter[0] }
            dialog = ProviderPreferencesDialog.new(@preferences_dialog, provider)
            dialog.show_all.run
            dialog.destroy
        end

        def on_providers_button_press_event(widget, event)
            # double left click
            if event.event_type == Gdk::Event::BUTTON2_PRESS and
               event.button == 1 

                on_setup
            end
        end
        
        def on_close
            @preferences_dialog.destroy
        end
    end
end
end
