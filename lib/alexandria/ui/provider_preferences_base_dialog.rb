# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

class Gtk::Entry
  attr_writer :mandatory

  def mandatory?
    @mandatory
  end
end

module Alexandria
  module UI
    class ProviderPreferencesBaseDialog
      attr_reader :dialog

      def initialize(title:, parent:, flags:, buttons:)
        @dialog = Gtk::Dialog.new(title: title, parent: parent, flags: flags,
                                 buttons: buttons)

        @dialog.resizable = false
        @dialog.child.border_width = 12

        @controls = []
      end

      private

      def fill_table(table, provider)
        i = table.n_rows
        table.resize(table.n_rows + provider.prefs.length,
                     table.n_columns)
        table.border_width = 12
        table.row_spacings = 6
        table.column_spacings = 12

        @controls.clear

        provider.prefs.read.each do |variable|
          if variable.name == "piggyback"
            next
            # ULTRA-HACK!! for bug #13302
            # not displaying the visual choice, as its usually unnecessary
            # Either way, this is confusing to the user: FIX
            #    -   Cathal Mc Ginley 2008-02-18
          end

          if variable.name == "enabled"
            # also don't display Enabled/Disabled
            next
          end

          label = Gtk::Label.new("_" + variable.description + ":")
          label.use_underline = true
          label.xalign = 0
          table.attach_defaults(label, 0, 1, i, i + 1)

          if variable.possible_values.nil?
            entry = Gtk::Entry.new
            entry.text = variable.value.to_s
            entry.mandatory = variable.mandatory?
          else
            entry = Gtk::ComboBoxText.new
            variable.possible_values.each do |value|
              entry.append_text(value.to_s)
            end
            index = variable.possible_values.index(variable.value)
            entry.active = index
          end
          label.mnemonic_widget = entry

          @controls << [variable, entry]

          table.attach_defaults(entry, 1, 2, i, i + 1)
          i += 1
        end
        table
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
  end
end
