# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require 'alexandria/ui/alert_dialog'

module Alexandria
  module UI
    class KeepBadISBNDialog < AlertDialog
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: 'UTF-8')

      def initialize(parent, book)
        title = _("Invalid ISBN '%s'") % book.isbn
        message = _("The book titled '%s' has an invalid ISBN, but still " \
                    'exists in the providers libraries.  Do you want to ' \
                    'keep the book but change the ISBN or cancel the addition?') % book.title
        super(parent, title,
              Gtk::Stock::DIALOG_QUESTION,
              [[Gtk::Stock::CANCEL, Gtk::ResponseType::CANCEL],
               [_('_Keep'), Gtk::ResponseType::OK]], message)
        self.default_response = Gtk::ResponseType::OK
      end

      def keep?
        show_all
        @response = run
        destroy
        @response == Gtk::ResponseType::OK
      end
    end
  end
end
