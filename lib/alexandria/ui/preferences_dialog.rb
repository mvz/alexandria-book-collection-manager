# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "alexandria/scanners/cue_cat"
require "alexandria/scanners/keyboard"
require "alexandria/ui/builder_base"
require "alexandria/ui/provider_preferences_dialog"
require "alexandria/ui/new_provider_dialog"

module Alexandria
  module UI
    class PreferencesDialog < BuilderBase
      include Logging
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

      def initialize(parent, &changed_block)
        super("preferences_dialog__builder.glade", widget_names)
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
            checkbutton.active = Preferences.instance.get_variable(pref_name)
          else
            log.warn do
              "no CheckButton for property #{pref_name} " \
              "(probably conflicting versions of GUI and lib code)"
            end
          end
        end

        model = Gtk::ListStore.new(String, String, TrueClass, Integer)
        @treeview_providers.model = model
        reload_providers
        model.signal_connect_after("row-changed") { update_priority }

        renderer = Gtk::CellRendererToggle.new
        renderer.activatable = true
        renderer.signal_connect("toggled") do |_rndrr, path|
          tree_path = Gtk::TreePath.new(path)
          @treeview_providers.selection.select_path(tree_path)
          prov = selected_provider
          if prov
            prov.toggle_enabled
            adjust_selected_provider(prov)
            # reload_providers
          end
        end

        # renderer.active = true
        column = Gtk::TreeViewColumn.new("Enabled", renderer)
        column.set_cell_data_func(renderer) do |_col, rndr, _mod, iter|
          value = iter[2]
          rndr.active = value
        end

        @treeview_providers.append_column(column)

        renderer = Gtk::CellRendererText.new
        column = Gtk::TreeViewColumn.new("Providers",
                                         renderer)
        column.set_cell_data_func(renderer) do |_col, rndr, _mod, iter|
          rndr.markup = iter[0]
        end
        @treeview_providers.append_column(column)
        @treeview_providers.selection
          .signal_connect("changed") { sensitize_providers }

        @button_prov_setup.sensitive = false

        @button_prov_up.sensitive =
          @button_prov_down.sensitive = BookProviders.list.length > 1

        @buttonbox_prov.set_child_secondary(@button_prov_add, true)
        @buttonbox_prov.set_child_secondary(@button_prov_remove, true)

        if BookProviders.abstract_classes.empty?
          @checkbutton_prov_advanced.sensitive = false
        else
          view_advanced = Preferences.instance.view_advanced_settings
          @checkbutton_prov_advanced.active = true if view_advanced
        end

        sensitize_providers
        setup_barcode_scanner_tab
      end

      def show
        @preferences_dialog.show
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
        @scanner_device_type.add_attribute(renderer, "text", 0)

        Alexandria::Scanners.each_scanner do |scanner|
          iter = @scanner_device_model.append
          iter[0] = scanner.display_name
          iter[1] = scanner.name
          @scanner_device_type.active = index if chosen_scanner_name == scanner.name
          index += 1
        end

        @use_scanning_sound.active = Preferences.instance.play_scanning_sound
        @use_scan_sound.active = Preferences.instance.play_scan_sound
      end

      def event_is_right_click(event)
        (event.event_type == :button_press) && (event.button == 3)
      end

      def prefs_empty(prefs)
        prefs.empty? || ((prefs.size == 1) && (prefs.first.name == "enabled"))
      end

      def on_provider_setup
        provider = selected_provider
        unless prefs_empty(provider.prefs)
          ProviderPreferencesDialog.new(@preferences_dialog, provider).acquire
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
        provider = NewProviderDialog.new(@preferences_dialog).acquire
        return unless provider

        BookProviders.instance.update_priority
        reload_providers
      end

      def on_scanner_device_type(_combo)
        iter = @scanner_device_type.active_iter
        Preferences.instance.barcode_scanner = iter[1] if iter && iter[1]
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
                                 _("Are you sure you want to " \
                                   "permanently delete the provider " \
                                   "'%s'?") % provider.fullname,
                                 Gtk::STOCK_DIALOG_QUESTION,
                                 [[Gtk::STOCK_CANCEL,
                                   Gtk::ResponseType::CANCEL],
                                  [Gtk::STOCK_DELETE,
                                   Gtk::ResponseType::OK]],
                                 _("If you continue, the provider and " \
                                   "all of its preferences will be " \
                                   "permanently deleted."))
        dialog.default_response = Gtk::ResponseType::CANCEL
        dialog.show_all
        if dialog.run == Gtk::ResponseType::OK
          provider.remove
          BookProviders.instance.update_priority
          reload_providers
        end
        dialog.destroy
      end

      def on_column_toggled(checkbutton)
        raise if @cols[checkbutton].nil?

        Preferences.instance.set_variable(@cols[checkbutton], checkbutton.active?)

        @changed_block.call
      end

      def on_providers_button_press_event(_widget, event)
        # double left click
        on_provider_setup if (event.event_type == :'2button_press') && (event.button == 1)
      end

      def on_close
        @preferences_dialog.destroy
        Alexandria::Preferences.instance.save!
      end

      def on_help
        Alexandria::UI.display_help(@preferences_dialog,
                                    "alexandria-preferences")
      end

      private

      def reload_providers
        model = @treeview_providers.model
        model.clear
        BookProviders.list.each_with_index do |x, index|
          iter = model.append
          iter[0] = if x.enabled
                      x.fullname
                    else
                      "<i>#{x.fullname}</i>"
                    end
          iter[1] = x.name
          iter[2] = x.enabled
          iter[3] = index
        end
      end

      def selected_provider
        iter = @treeview_providers.selection.selected
        BookProviders.list.find { |x| x.name == iter[1] } unless iter.nil?
      end

      def adjust_selected_provider(prov)
        iter = @treeview_providers.selection.selected
        iter[0] = if prov.enabled
                    prov.fullname
                  else
                    "<i>#{prov.fullname}</i>"
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
          last_iter = model.get_iter((BookProviders.list.length - 1).to_s)
          @button_prov_up.sensitive = sel_iter != model.iter_first
          @button_prov_down.sensitive = sel_iter != last_iter
          provider = BookProviders.list.find { |x| x.name == sel_iter[1] }
          @button_prov_setup.sensitive = !prefs_empty(provider.prefs)
          @button_prov_remove.sensitive = provider.abstract?
        end
      end

      def update_priority
        priority = []
        @treeview_providers.model.each do |_model, _path, iter|
          priority << iter[1]
        end
        Preferences.instance.providers_priority = priority
        BookProviders.instance.update_priority
      end
    end
  end
end
