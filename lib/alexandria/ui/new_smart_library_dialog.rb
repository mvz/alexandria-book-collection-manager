# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

module Alexandria
  module UI
    class NewSmartLibraryDialog < SmartLibraryPropertiesDialogBase
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

      def initialize(parent)
        super(parent)

        add_buttons([Gtk::Stock::CANCEL, :cancel],
                    [Gtk::Stock::NEW, :ok])

        self.title = _("New Smart Library")
        # FIXME: Should accept just :cancel
        self.default_response = Gtk::ResponseType::CANCEL
        insert_new_rule
      end

      def acquire
        show_all

        result = nil
        while ((response = run) != Gtk::ResponseType::CANCEL) &&
            (response != Gtk::ResponseType::DELETE_EVENT)

          if response == Gtk::ResponseType::HELP
            handle_help_response
          elsif response == Gtk::ResponseType::OK
            result = handle_ok_response
            break if result
          end
        end

        destroy
        result
      end

      def handle_help_response
        Alexandria::UI.display_help(self, "new-smart-library")
      end

      def handle_ok_response
        if user_confirms_possible_weirdnesses_before_saving?
          rules = smart_library_rules
          basename = smart_library_base_name(rules) || _("Smart Library")
          name = Library.generate_new_name(
            LibraryCollection.instance.all_libraries,
            basename)
          library_store = LibraryCollection.instance.library_store
          library = SmartLibrary.new(name,
                                     rules,
                                     predicate_operator_rule,
                                     library_store)
          return library
        end
      end

      private

      def smart_library_base_name(rules)
        return unless rules.length == 1

        value = rules.first.value
        value if value.is_a?(String) && !value.strip.empty?
      end
    end
  end
end
