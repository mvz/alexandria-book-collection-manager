# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "alexandria/ui/provider_preferences_base_dialog"

module Alexandria
  module UI
    class NewProviderDialog < ProviderPreferencesBaseDialog
      include GetText

      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

      def initialize(parent)
        super(title: _("New Provider"),
              parent: parent,
              flags: :modal,
              buttons: [[Gtk::STOCK_CANCEL, Gtk::ResponseType::CANCEL]])
        @add_button = dialog.add_button(Gtk::STOCK_ADD,
                                        Gtk::ResponseType::ACCEPT)

        instances = BookProviders.abstract_classes.map(&:new)
        @selected_instance = nil

        @table = Gtk::Table.new(2, 2, false)
        dialog.child.pack_start(@table, false, false, 0)

        # Name.

        label_name = Gtk::Label.new(_("_Name:"))
        label_name.use_underline = true
        label_name.xalign = 0
        @table.attach_defaults(label_name, 0, 1, 0, 1)

        @entry_name = Gtk::Entry.new
        @entry_name.mandatory = true
        label_name.mnemonic_widget = @entry_name
        @table.attach_defaults(@entry_name, 1, 2, 0, 1)

        # Type.

        label_type = Gtk::Label.new(_("_Type:"))
        label_type.use_underline = true
        label_type.xalign = 0
        @table.attach_defaults(label_type, 0, 1, 1, 2)

        combo_type = Gtk::ComboBoxText.new
        instances.each do |instance|
          combo_type.append_text(instance.name)
        end
        combo_type.signal_connect("changed") do |cb|
          @selected_instance = instances[cb.active]
          fill_table(@table, @selected_instance)
          sensitize
          # FIXME: this should be re-written once we have multiple
          # abstract providers.
        end
        combo_type.active = 0
        label_type.mnemonic_widget = combo_type
        @table.attach_defaults(combo_type, 1, 2, 1, 2)
      end

      def acquire
        dialog.show_all
        if dialog.run == Gtk::ResponseType::ACCEPT
          @selected_instance.reinitialize(@entry_name.text)
          sync_variables
        else
          @selected_instance = nil
        end
        dialog.destroy
        instance
      end

      def instance
        @selected_instance
      end

      private

      def sensitize
        entries = @table.children.select { |x| x.is_a?(Gtk::Entry) }
        entries.each do |entry|
          entry.signal_connect("changed") do
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
  end
end
