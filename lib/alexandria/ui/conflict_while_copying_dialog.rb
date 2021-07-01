# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "alexandria/ui/alert_dialog"

module Alexandria
  module UI
    class ConflictWhileCopyingDialog < AlertDialog
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

      def initialize(parent, library, book)
        super(parent,
              format(_("The book '%s' already exists in '%s'. Would you like " \
                       "to replace it?"), book.title, library.name),
              Gtk::Stock::DIALOG_QUESTION,
              [[_("_Skip"), Gtk::ResponseType::CANCEL],
               [_("_Replace"), Gtk::ResponseType::OK]],
              _("If you replace the existing book, its contents will " \
                "be overwritten."))
        dialog.default_response = Gtk::ResponseType::CANCEL
      end

      def replace?
        show_all && (@response = run)
        destroy
        @response == Gtk::ResponseType::OK
      end
    end
  end
end
