# Copyright (C) 2004-2006 Laurent Sansonetti
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

require 'alexandria/scanners/cuecat'
require 'alexandria/scanners/keyboard'

class Gtk::Entry
  attr_writer :mandatory
  def mandatory?
    @mandatory
  end
end

module Alexandria
  module UI
    class ProviderPreferencesBaseDialog < Gtk::Dialog
      def initialize(*args)
        super(*args)

        self.has_separator = false
        self.resizable = false
        self.vbox.border_width = 12

        @controls = []
      end

      def fill_table(table, provider)
        i = table.n_rows
        table.resize(table.n_rows + provider.prefs.length,
                     table.n_columns)
        table.border_width = 12
        table.row_spacings = 6
        table.column_spacings = 12

        @controls.clear

        provider.prefs.read.each do |variable|
          if variable.name == 'piggyback'
            next
            # ULTRA-HACK!! for bug #13302
            # not displaying the visual choice, as its usually unnecessary
            # Either way, this is confusing to the user: FIX
            #    -   Cathal Mc Ginley 2008-02-18
          end

          if variable.name == 'enabled'
            # also don't display Enabled/Disabled
            next
          end

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
          else
            entry = Gtk::Entry.new
            entry.text = variable.value.to_s
            entry.mandatory = variable.mandatory?
          end
          label.mnemonic_widget = entry

          @controls << [variable, entry]

          table.attach_defaults(entry, 1, 2, i, i + 1)
          i += 1
        end
        return table
      end

      def sync_variables
        @controls.each do |variable, entry|
          variable.new_value = case entry
                               when Gtk::ComboBox
                                 variable.possible_values[entry.active]
                               when Gtk::Entry
                                 entry.text
                               end
        end
      end
    end

    class ProviderPreferencesDialog < ProviderPreferencesBaseDialog
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")

      def initialize(parent, provider)
        super(_("Preferences for %s") % provider.fullname,
              parent,
              Gtk::Dialog::MODAL,
              [ Gtk::Stock::CLOSE, Gtk::Dialog::RESPONSE_CLOSE ])
        self.has_separator = false
        self.resizable = false
        self.vbox.border_width = 12

        table = Gtk::Table.new(0, 0)
        fill_table(table, provider)
        self.vbox.pack_start(table)

        self.signal_connect('destroy') { sync_variables }

        show_all
        run
        destroy
      end
    end

    class NewProviderDialog <  ProviderPreferencesBaseDialog
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")

      def initialize(parent)
        super(_("New Provider"),
              parent,
              Gtk::Dialog::MODAL,
              [ Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL ])
        @add_button = add_button(Gtk::Stock::ADD,
                                 Gtk::Dialog::RESPONSE_ACCEPT)

        instances = BookProviders::abstract_classes.map { |x| x.new }
        @selected_instance = nil

        @table = Gtk::Table.new(2, 2)
        self.vbox.pack_start(@table)

        # Name.

        label_name = Gtk::Label.new(_("_Name:"))
        label_name.use_underline = true
        label_name.xalign = 0
        @table.attach_defaults(label_name, 0, 1, 0, 1)

        entry_name = Gtk::Entry.new
        entry_name.mandatory = true
        label_name.mnemonic_widget = entry_name
        @table.attach_defaults(entry_name, 1, 2, 0, 1)

        # Type.

        label_type = Gtk::Label.new(_("_Type:"))
        label_type.use_underline = true
        label_type.xalign = 0
        @table.attach_defaults(label_type, 0, 1, 1, 2)

        combo_type = Gtk::ComboBox.new
        instances.each do |instance|
          combo_type.append_text(instance.name)
        end
        combo_type.signal_connect('changed') do |cb|
          @selected_instance = instances[cb.active]
          fill_table(@table, @selected_instance)
          sensitize
          # FIXME this should be re-written once we have multiple
          # abstract providers.
        end
        combo_type.active = 0
        label_type.mnemonic_widget = combo_type
        @table.attach_defaults(combo_type, 1, 2, 1, 2)

        show_all
        if run == Gtk::Dialog::RESPONSE_ACCEPT
          @selected_instance.reinitialize(entry_name.text)
          sync_variables
        else
          @selected_instance = nil
        end
        destroy
      end

      def instance
        @selected_instance
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
              if entry2.mandatory?
                sensitive = !entry2.text.strip.empty?
                break unless sensitive
              end
            end
            @add_button.sensitive = sensitive
          end
        end
        @add_button.sensitive = false
      end
    end

    class PreferencesDialog < BuilderBase
      include Alexandria::Logging
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")

      def initialize(parent, &changed_block)
        super('preferences_dialog__builder.glade', widget_names)
        @preferences_dialog.transient_for = parent
        @changed_block = changed_block

        @cols = {
          @checkbutton_col_authors      => "col_authors_visible",
          @checkbutton_col_isbn         => "col_isbn_visible",
          @checkbutton_col_publisher    => "col_publisher_visible",
          @checkbutton_col_publish_date => "col_publish_date_visible",
          @checkbutton_col_edition      => "col_edition_visible",
          @checkbutton_col_redd         => "col_redd_visible",
          @checkbutton_col_own          => "col_own_visible",
          @checkbutton_col_want         => "col_want_visible",
          @checkbutton_col_rating       => "col_rating_visible",
          @checkbutton_col_tags         => "col_tags_visible",
          @checkbutton_col_loaned_to    => "col_loaned_to_visible"
        }
        @cols.each_pair do |checkbutton, pref_name|
          if checkbutton
            checkbutton.active = Preferences.instance.send(pref_name)
          else
            log.warn { "no CheckButton for property #{pref_name} " +
              "(probably conflicting versions of GUI and lib code)" }
          end
        end

        model = Gtk::ListStore.new(String, String, TrueClass, Integer)
        @treeview_providers.model = model
        reload_providers
        model.signal_connect_after('row-changed') { update_priority }

        renderer= Gtk::CellRendererToggle.new
        renderer.activatable = true
        renderer.signal_connect('toggled') do |rndrr, path|
          tree_path = Gtk::TreePath.new(path)
          @treeview_providers.selection.select_path(tree_path)
          prov = selected_provider
          if prov
            prov.toggle_enabled()
            adjust_selected_provider(prov)
            # reload_providers
          end
        end

        #renderer.active = true
        column = Gtk::TreeViewColumn.new("Enabled", renderer)
        column.set_cell_data_func(renderer) do |col, renderer, model, iter|
          value = iter[2]
          renderer.active = value
        end

       

        @treeview_providers.append_column(column)

        renderer = Gtk::CellRendererText.new
        column = Gtk::TreeViewColumn.new("Providers",
                                         renderer)
                                         # :text => 0)
        column.set_cell_data_func(renderer) do |col, renderer, model, iter|
          renderer.markup = iter[0]
          #enabled = iter[2]
          #unless enabled
          #  renderer.foreground = "gray"
          #end
          #renderer.active = value
        end
        @treeview_providers.append_column(column)
        @treeview_providers.selection.signal_connect('changed') \
        { sensitize_providers }

        @button_prov_setup.sensitive = false
        @button_prov_up.sensitive =  @button_prov_down.sensitive =
          BookProviders.length > 1

        @buttonbox_prov.set_child_secondary(@button_prov_add, true)
        @buttonbox_prov.set_child_secondary(@button_prov_remove, true)

        if BookProviders::abstract_classes.empty?
          @checkbutton_prov_advanced.sensitive = false
        else
          view_advanced = Preferences.instance.view_advanced_settings
          if view_advanced
            @checkbutton_prov_advanced.active = true
          end
        end

        
        setup_enable_disable_popup
        sensitize_providers
        setup_barcode_scanner_tab
      end


      def widget_names
        [:button_prov_add, :button_prov_down, :button_prov_remove,
         :button_prov_setup, :button_prov_up, :buttonbox_prov,
         :checkbutton_col_authors, :checkbutton_col_edition,
         :checkbutton_col_isbn, :checkbutton_col_loaned_to,
         :checkbutton_col_own, :checkbutton_col_publish_date,
         :checkbutton_col_publisher, :checkbutton_col_rating,
         :checkbutton_col_redd, :checkbutton_col_tags,
         :checkbutton_col_want, :checkbutton_prov_advanced,
         :preferences_dialog, :treeview_providers,
         :scanner_device_type, :use_scanning_sound, :use_scan_sound]
      end

      def setup_barcode_scanner_tab
        @scanner_device_model = Gtk::ListStore.new(String, String)
        chosen_scanner_name = Preferences.instance.barcode_scanner
        index = 0
        @scanner_device_type.model = @scanner_device_model
        renderer = Gtk::CellRendererText.new
        @scanner_device_type.pack_start(renderer, true)
        @scanner_device_type.add_attribute(renderer, 'text', 0)
        
        Alexandria::Scanners::Registry.each do |scanner|
          iter = @scanner_device_model.append
          iter[0] = scanner.display_name
          iter[1] = scanner.name
          if (chosen_scanner_name == scanner.name)
            @scanner_device_type.active = index
          end
          index += 1
        end


        @use_scanning_sound.active = Preferences.instance.play_scanning_sound
        @use_scan_sound.active = Preferences.instance.play_scan_sound
      end

      def setup_enable_disable_popup
        # New Enable/Disable pop-up menu...
        @enable_disable_providers_menu = Gtk::Menu.new
        @enable_item = Gtk::MenuItem.new(_("Disable Provider"))
        @enable_item.signal_connect("activate") { 
          prov = selected_provider
          prov.toggle_enabled()
          adjust_selected_provider(prov)
          
        }
        @enable_disable_providers_menu.append(@enable_item)
        @enable_disable_providers_menu.show_all
        

        @treeview_providers.signal_connect("button_press_event") do |widget, event|
          if event_is_right_click(event)
            if path = widget.get_path_at_pos(event.x, event.y)
              widget.grab_focus
              obj, path = widget.selection, path.first
              unless obj.path_is_selected?(path)
                widget.unselect_all
                obj.select_path(path)
              end
              sel = widget.selection.selected
              if sel
                already_enabled = sel[2]
                message = already_enabled ? _("Disable Provider") : _("Enable Provider")
                @enable_item.label = message
                Gtk.idle_add do
                  @enable_disable_providers_menu.popup(nil, nil, event.button, event.time)
                  false
                end
              end
            else
              puts "not on a path"
            end
          end
        end

        # Popup the menu on Shift-F10
        @treeview_providers.signal_connect("popup_menu") { 
          selected_prov = @treeview_providers.selection.selected
          puts selected_prov.inspect
          if selected_prov
            Gtk.idle_add do
              already_enabled = selected_prov[2]
              message = already_enabled ? _("Disable Provider") : _("Enable Provider")
              @enable_item.label = message

              @enable_disable_providers_menu.popup(nil, nil, 0, Gdk::Event::CURRENT_TIME) 
              false
            end
          else
            puts "no action"
          end
          }
      end

      def event_is_right_click(event)
        event.event_type == Gdk::Event::BUTTON_PRESS and event.button == 3
      end


      def prefs_empty(prefs)
        prefs.empty? or (prefs.size == 1 and prefs.first.name == "enabled")
      end

      def on_provider_setup
        provider = selected_provider
        unless prefs_empty(provider.prefs)
          ProviderPreferencesDialog.new(@preferences_dialog, provider)
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
        Preferences.instance.view_advanced_settings = on
        @button_prov_add.visible = @button_prov_remove.visible = on
      end

      def on_provider_add
        dialog = NewProviderDialog.new(@preferences_dialog)
        if new_provider = dialog.instance
          BookProviders.update_priority
          reload_providers
        end
      end



      def on_scanner_device_type(combo)
        iter = @scanner_device_type.active_iter
        if iter && iter[1]
          Preferences.instance.barcode_scanner = iter[1]
        end
      end

      def on_use_scanning_sound(checkbox)
        Preferences.instance.play_scanning_sound = checkbox.active?
      end

      def on_use_scan_sound(checkbox)
        Preferences.instance.play_scan_sound = checkbox.active?
      end


      def on_provider_remove
        provider = selected_provider
        dialog = AlertDialog.new(@main_app,
                                 _("Are you sure you want to " +
                                   "permanently delete the provider " +
                                   "'%s'?") % provider.fullname,
                                 Gtk::Stock::DIALOG_QUESTION,
                                 [[Gtk::Stock::CANCEL,
                                   Gtk::Dialog::RESPONSE_CANCEL],
                                  [Gtk::Stock::DELETE,
                                   Gtk::Dialog::RESPONSE_OK]],
                                 _("If you continue, the provider and " +
                                   "all of its preferences will be " +
                                   "permanently deleted."))
        dialog.default_response = Gtk::Dialog::RESPONSE_CANCEL
        dialog.show_all
        if dialog.run == Gtk::Dialog::RESPONSE_OK
          provider.remove
          BookProviders.update_priority
          reload_providers
        end
        dialog.destroy
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
        Alexandria::Preferences.instance.save!
      end

      def on_help
        Alexandria::UI::display_help(@preferences_dialog,
                                     'alexandria-preferences')
      end

      #######
      private
      #######

      def reload_providers
        model = @treeview_providers.model
        model.clear
        BookProviders.each_with_index do |x, index|
          iter = model.append
          if x.enabled
            iter[0] = x.fullname
          else
            iter[0] = "<i>#{x.fullname}</i>"
          end
          iter[1] = x.name
          iter[2] = x.enabled
          iter[3] = index
        end
      end

      def selected_provider
        iter = @treeview_providers.selection.selected
        unless iter.nil?
          BookProviders.find { |x| x.name == iter[1] }
        end
      end

      def adjust_selected_provider(prov)
        iter = @treeview_providers.selection.selected
        if prov.enabled
          iter[0] = prov.fullname
        else
          iter[0] = "<i>#{prov.fullname}</i>"
        end
        iter[2] = prov.enabled
      end

      def sensitize_providers
        model = @treeview_providers.model
        sel_iter = @treeview_providers.selection.selected
        if sel_iter.nil?
          # No selection, we are probably called by ListStore#clear
          @button_prov_up.sensitive = false
          @button_prov_down.sensitive = false
          @button_prov_setup.sensitive = false
          @button_prov_remove.sensitive = false
        else
          last_iter = model.get_iter((BookProviders.length - 1).to_s)
          @button_prov_up.sensitive = sel_iter != model.iter_first
          @button_prov_down.sensitive = sel_iter != last_iter
          provider = BookProviders.find { |x| x.name == sel_iter[1] }
          @button_prov_setup.sensitive = (not prefs_empty(provider.prefs))
          @button_prov_remove.sensitive = provider.abstract?
        end
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
