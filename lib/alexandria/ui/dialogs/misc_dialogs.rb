# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

module Alexandria
  module UI
    class ConflictWhileCopyingDialog < AlertDialog
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: 'UTF-8')

      def initialize(parent, library, book)
        super(parent,
              format(_("The book '%s' already exists in '%s'. Would you like " \
                'to replace it?'), book.title, library.name),
              Gtk::Stock::DIALOG_QUESTION,
              [[_('_Skip'), Gtk::ResponseType::CANCEL],
               [_('_Replace'), Gtk::ResponseType::OK]],
              _('If you replace the existing book, its contents will ' \
                'be overwritten.'))
        self.default_response = Gtk::ResponseType::CANCEL
      end

      def replace?
        show_all && (@response = run)
        destroy
        @response == Gtk::ResponseType::OK
      end
    end

    class ReallyDeleteDialog < AlertDialog
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: 'UTF-8')

      def initialize(parent, library, books = nil)
        # Deleting a library.
        if books.nil?
          message = _("Are you sure you want to delete '%s'?") % library.name
          description = if library.is_a?(SmartLibrary) || library.empty?
                          nil
                        else
                          n_('If you continue, %d book will be deleted.',
                             'If you continue, %d books will be deleted.',
                             library.size) % library.size
                        end
          # Deleting books.
        else
          message = if books.length == 1
                      format(_("Are you sure you want to delete '%s' " \
                        "from '%s'?"), books.first.title, library.name)
                    else
                      _('Are you sure you want to delete the ' \
                        "selected books from '%s'?") % library.name
                    end
          description = nil
        end

        super(parent, message, Gtk::Stock::DIALOG_QUESTION,
              [[Gtk::Stock::CANCEL, Gtk::ResponseType::CANCEL],
               [Gtk::Stock::DELETE, Gtk::ResponseType::OK]],
              description)

        self.default_response = Gtk::ResponseType::CANCEL
      end

      def ok?
        show_all && (@response = run)
        destroy
        @response == Gtk::ResponseType::OK
      end
    end
  end
end
