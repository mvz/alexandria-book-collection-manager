# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "alexandria/ui/alert_dialog"

module Alexandria
  module UI
    class ErrorDialog < AlertDialog
      def initialize(parent, title, message = nil)
        super(parent, title, Gtk::STOCK_DIALOG_ERROR,
              [[Gtk::STOCK_OK, :ok]], message)
        # FIXME: Should accept just :ok
        dialog.default_response = Gtk::ResponseType::OK
      end

      def display
        show_all && run
        destroy
      end
    end
  end
end
