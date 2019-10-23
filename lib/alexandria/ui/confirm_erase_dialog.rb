# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "alexandria/ui/alert_dialog"

module Alexandria
  module UI
    class ConfirmEraseDialog < AlertDialog
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

      def initialize(parent, filename)
        super(parent, _("File already exists"),
              Gtk::Stock::DIALOG_QUESTION,
              [[Gtk::Stock::CANCEL, :cancel],
               [_("_Replace"), :ok]],
              _("A file named '%s' already exists.  Do you want " \
                "to replace it with the one you are generating?") % filename)
        # FIXME: Should accept just :cancel
        self.default_response = Gtk::ResponseType::CANCEL
      end

      def erase?
        show_all && (@response = run)
        destroy
        @response == Gtk::ResponseType::OK
      end
    end
  end
end
