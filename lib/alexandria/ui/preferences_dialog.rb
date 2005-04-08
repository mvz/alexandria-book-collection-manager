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

module Alexandria
module UI
    class ProviderPreferencesBaseDialog < Gtk::Dialog
        def initialize(*args)
            super(*args)
            
            self.has_separator = false
            self.resizable = false
            self.vbox.border_width = 12
        end

        def table_preferences_for_provider(provider, table=nil)
            unless table
                i = 0
                table = Gtk::Table.new(provider.prefs.length, 2)
            else
                i = table.n_rows
                table.resize(table.n_rows + provider.prefs.length,
                             table.n_columns)
            end 
            table.border_width = 12
            table.row_spacings = 6 
            table.column_spacings = 12
            provider.prefs.read.each do |variable|
                label = Gtk::Label.new("_" + variable.description + ":")
                label.use_underline = true
                label.xalign = 0
                table.attach_defaults(label, 0, 1, i, i + 1)
               
                unless variable.possible_values.nil?
                    entry = Gtk::ComboBox.new
                    variable.possible_values.each do |value|
                        entry.append_text(value.to_s)
                    end
                    index = variable.possible_values.index(variable.value)
                    entry.active = index 
                    entry.signal_connect('changed') do |cb|
                        value = variable.possible_values[cb.active]
                        variable.new_value = value
                    end
                else
                    entry = Gtk::Entry.new
                    entry.text = variable.value.to_s
                    entry.signal_connect('changed') do |entry|
                        variable.new_value = entry.text 
                    end
                end
                label.mnemonic_widget = entry

                table.attach_defaults(entry, 1, 2, i, i + 1)
                i += 1
            end
            return table
        end
    end

    class ProviderPreferencesDialog < ProviderPreferencesBaseDialog 
        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        def initialize(parent, provider)
            super(_("Preferences for %s") % provider.fullname,
                  parent,
                  Gtk::Dialog::MODAL,
                  [ Gtk::Stock::CLOSE, Gtk::Dialog::RESPONSE_CLOSE ])
            self.has_separator = false
            self.resizable = false
            self.vbox.border_width = 12
            
            table = table_preferences_for_provider(provider)
            self.vbox.pack_start(table)
        end
    end
    
    class NewProviderDialog <  ProviderPreferencesBaseDialog
        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        def initialize(parent)
            super(_("New Provider"),
                  parent,
                  Gtk::Dialog::MODAL,
                  [ Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL ])
            @add_button = add_button(Gtk::Stock::ADD, 
                                     Gtk::Dialog::RESPONSE_ACCEPT)

            instances = BookProviders::abstract_classes.map { |x| x.instance }
            first_instance = instances.first
  
            @table = Gtk::Table.new(2, 2)
            self.vbox.pack_start(@table)

            # Name.
   
            label = Gtk::Label.new(_("_Name:"))
            label.use_underline = true
            label.xalign = 0
            @table.attach_defaults(label, 0, 1, 0, 1)
            
            entry = Gtk::Entry.new
            label.mnemonic_widget = entry
            @table.attach_defaults(entry, 1, 2, 0, 1)
            
            # Type.

            label = Gtk::Label.new(_("_Type:"))
            label.use_underline = true
            label.xalign = 0
            @table.attach_defaults(label, 0, 1, 1, 2)
            
            entry = Gtk::ComboBox.new
            instances.each do |instance|
                entry.append_text(instance.name)
                table_preferences_for_provider(first_instance, @table)
                sensitize
                # FIXME this should be re-written once we have multiple
                # abstract providers.
            end
            entry.signal_connect('changed') do |cb|
                instance = instances[cb.active]
            end
            entry.active = 0
            label.mnemonic_widget = entry
            @table.attach_defaults(entry, 1, 2, 1, 2)
 
            @add_button.signal_connect('clicked') {}
        end

        def instance
            # TODO
        end

        #######
        private
        #######

        def sensitize
            entries = @table.children.select { |x| x.is_a?(Gtk::Entry) }
            entries.each do |entry|
                entry.signal_connect('changed') do
                    sensitive = true
                    entries.each do |entry2|
                        sensitive = !entry2.text.strip.empty?
                        break unless sensitive
                    end
                    @add_button.sensitive = sensitive
                end
            end
            @add_button.sensitive = false 
        end
    end

    class PreferencesDialog < GladeBase
        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        def initialize(parent, &changed_block)
            super('preferences_dialog.glade')
            @preferences_dialog.transient_for = parent
            @changed_block = changed_block

            @cols = {
                @checkbutton_col_authors   => "col_authors_visible",
                @checkbutton_col_isbn      => "col_isbn_visible",
                @checkbutton_col_publisher => "col_publisher_visible",
                @checkbutton_col_edition   => "col_edition_visible",
                @checkbutton_col_rating    => "col_rating_visible"
            }
            @cols.each_pair do |checkbutton, pref_name|
                checkbutton.active = Preferences.instance.send(pref_name)
            end           
 
            model = Gtk::ListStore.new(String, String)
            BookProviders.each do |x| 
                iter = model.append
                iter[0] = x.fullname
                iter[1] = x.name
            end
            @treeview_providers.model = model
            column = Gtk::TreeViewColumn.new("Providers",
                                             Gtk::CellRendererText.new,
                                             :text => 0)
            @treeview_providers.append_column(column)
            @treeview_providers.selection.signal_connect('changed') \
                { sensitize_providers } 
            
            @button_prov_setup.sensitive = false
            @button_prov_up.sensitive =  @button_prov_down.sensitive = 
                BookProviders.length > 1
            
            @buttonbox_prov.set_child_secondary(@button_prov_add, true)
            @buttonbox_prov.set_child_secondary(@button_prov_remove, true)
        end

        def on_provider_setup
            iter = @treeview_providers.selection.selected
            provider = BookProviders.find { |x| x.name == iter[1] }
            unless provider.prefs.empty?
                dialog = ProviderPreferencesDialog.new(@preferences_dialog, 
                                                       provider)
                dialog.show_all.run
                dialog.destroy
            end
        end

        def on_provider_up
            iter = @treeview_providers.selection.selected
            previous_path = iter.path
            previous_path.prev!
            model = @treeview_providers.model
            model.move_after(model.get_iter(previous_path), iter)
            sensitize_providers
            update_priority
        end

        def on_provider_down
            iter = @treeview_providers.selection.selected
            next_iter = iter.dup
            next_iter.next!
            @treeview_providers.model.move_after(iter, next_iter)
            sensitize_providers
            update_priority
        end

        def on_provider_advanced_toggled(checkbutton)
            on = checkbutton.active?
            @button_prov_add.visible = @button_prov_remove.visible = on
        end

        def on_provider_add
            dialog = NewProviderDialog.new(@preferences_dialog)
            dialog.show_all.run
            dialog.destroy
            # TODO
        end

        def on_provider_remove
            # TODO
        end

        def on_column_toggled(checkbutton)
            raise if @cols[checkbutton].nil?
            Preferences.instance.send("#{@cols[checkbutton]}=", 
                                      checkbutton.active?)
            @changed_block.call
        end

        def on_providers_button_press_event(widget, event)
            # double left click
            if event.event_type == Gdk::Event::BUTTON2_PRESS and
               event.button == 1 

                on_provider_setup
            end
        end
        
        def on_close
            @preferences_dialog.destroy
        end

        def on_help
            begin
                Gnome::Help.display('alexandria', 'alexandria-preferences')
            rescue 
                ErrorDialog.new(@preferences_dialog, e.message)
            end
        end

        #######
        private
        #######

        def sensitize_providers 
            model = @treeview_providers.model 
            sel_iter = @treeview_providers.selection.selected
            last_iter = model.get_iter((BookProviders.length - 1).to_s)
            @button_prov_up.sensitive = sel_iter != model.iter_first
            @button_prov_down.sensitive = sel_iter != last_iter 
            provider = BookProviders.find { |x| x.name == sel_iter[1] }
            @button_prov_setup.sensitive = (not provider.prefs.empty?)
        end

        def update_priority
            priority = []
            @treeview_providers.model.each do |model, path, iter| 
                priority << iter[1]
            end
            Preferences.instance.providers_priority = priority
            BookProviders.update_priority
        end
    end
end
end
