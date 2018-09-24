# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "alexandria/ui/provider_preferences_base_dialog"

module Alexandria
  module UI
    class ProviderPreferencesDialog < ProviderPreferencesBaseDialog
      include GetText

      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

      def initialize(parent, provider)
        super(title: _("Preferences for %s") % provider.fullname,
              parent: parent,
              flags: :modal,
              buttons: [[Gtk::STOCK_CLOSE, :close]])

        table = Gtk::Table.new(0, 0, false)
        fill_table(table, provider)
        dialog.get_content_area.pack_start(table, false, false, 0)

        dialog.signal_connect("destroy") { sync_variables }
      end

      def acquire
        dialog.show_all
        dialog.run
        dialog.destroy
      end
    end
  end
end
