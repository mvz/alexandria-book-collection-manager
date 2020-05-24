# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "alexandria/ui/alert_dialog"

module Alexandria
  module UI
    class ReallyDeleteDialog < AlertDialog
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

      def initialize(parent, library, books = nil)
        # Deleting a library.
        if books.nil?
          message = _("Are you sure you want to delete '%s'?") % library.name
          description = if library.is_a?(SmartLibrary) || library.empty?
                          nil
                        else
                          n_("If you continue, %d book will be deleted.",
                             "If you continue, %d books will be deleted.",
                             library.size) % library.size
                        end
          # Deleting books.
        else
          message = if books.length == 1
                      format(_("Are you sure you want to delete '%s' " \
                        "from '%s'?"), books.first.title, library.name)
                    else
                      _("Are you sure you want to delete the " \
                        "selected books from '%s'?") % library.name
                    end
          description = nil
        end

        super(parent, message, Gtk::Stock::DIALOG_QUESTION,
              [[Gtk::Stock::CANCEL, Gtk::ResponseType::CANCEL],
               [Gtk::Stock::DELETE, Gtk::ResponseType::OK]],
              description)

        dialog.default_response = Gtk::ResponseType::CANCEL
      end

      def ok?
        show_all && (@response = run)
        destroy
        @response == Gtk::ResponseType::OK
      end
    end
  end
end
