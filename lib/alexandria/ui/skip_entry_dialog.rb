# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "alexandria/ui/alert_dialog"

module Alexandria
  module UI
    class SkipEntryDialog < AlertDialog
      include GetText
      include Logging

      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

      def initialize(parent, message)
        super(parent, _("Error while importing"),
              Gtk::STOCK_DIALOG_QUESTION,
              [[Gtk::STOCK_CANCEL, Gtk::ResponseType::CANCEL],
               [_("_Continue"), Gtk::ResponseType::OK]],
              message)
        log.debug { "Opened SkipEntryDialog #{inspect}" }
        dialog.default_response = Gtk::ResponseType::CANCEL
      end

      def continue?
        show_all && (@response = run)
        destroy
        @response == Gtk::ResponseType::OK
      end
    end
  end
end
