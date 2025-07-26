# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

module Alexandria
  module UI
    class SmartLibraryPropertiesDialog < SmartLibraryPropertiesDialogBase
      include GetText

      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

      def initialize(parent, smart_library)
        super(parent)

        @smart_library = smart_library

        dialog.add_buttons([Gtk::Stock::CANCEL, :cancel],
                           [Gtk::Stock::SAVE, :ok])

        dialog.title = _("Properties for '%s'") % @smart_library.name
        # FIXME: Should accept just :cancel
        dialog.default_response = Gtk::ResponseType::CANCEL
        @smart_library.rules.each { |x| insert_new_rule(x) }
        update_rules_header_box(@smart_library.predicate_operator_rule)
      end

      def acquire
        dialog.show_all

        while (response = dialog.run) != Gtk::ResponseType::CANCEL
          case response
          when Gtk::ResponseType::HELP
            handle_help_response
          when Gtk::ResponseType::OK
            break if handle_ok_response
          end
        end

        dialog.destroy
      end

      private

      def handle_ok_response
        user_confirms_possible_weirdnesses_before_saving? or return

        @smart_library.rules = smart_library_rules
        @smart_library.predicate_operator_rule =
          predicate_operator_rule
        @smart_library.save
        true
      end

      def handle_help_response
        Alexandria::UI.display_help(self, "edit-smart-library")
      end
    end
  end
end
