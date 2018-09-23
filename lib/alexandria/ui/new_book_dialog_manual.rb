# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "tmpdir"
require "alexandria/ui/error_dialog"

module Alexandria
  module UI
    class NewBookDialogManual < BookPropertiesDialogBase
      include GetText
      extend GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

      TMP_COVER_FILE = File.join(Dir.tmpdir, "tmp_cover")
      def initialize(parent, library, &on_add_cb)
        super(parent, TMP_COVER_FILE)

        @library = library
        @on_add_cb = on_add_cb
        FileUtils.rm_f(TMP_COVER_FILE)

        cancel_button = Gtk::Button.new(stock_id: Gtk::STOCK_CANCEL)
        cancel_button.signal_connect("clicked") { on_cancel }
        cancel_button.show
        @button_box << cancel_button

        add_button = Gtk::Button.new(stock_id: Gtk::STOCK_ADD)
        add_button.signal_connect("clicked") { on_add }
        add_button.show
        @button_box << add_button

        help_button = Gtk::Button.new(stock_id: Gtk::STOCK_HELP)
        help_button.signal_connect("clicked") { on_help }
        help_button.show
        @button_box << help_button
        @button_box.set_child_secondary(help_button, true)

        self.rating = Book::DEFAULT_RATING
        self.cover = Icons::BOOK_ICON

        on_title_changed
      end

      def on_title_changed
        title = @entry_title.text.strip
        @book_properties_dialog.title = if title.empty?
                                          _("Adding a Book")
                                        else
                                          _("Adding '%s'") % title
                                        end
      end

      private

      def on_cancel
        @book_properties_dialog.destroy
      end

      class AddError < StandardError
      end

      def on_add
        if (title = @entry_title.text.strip).empty?
          raise AddError, _("A title must be provided.")
        end

        isbn = nil
        if @entry_isbn.text != ""
          isbn = Library.canonicalise_ean(@entry_isbn.text)
          unless isbn
            raise AddError, _("Couldn't validate the EAN/ISBN you provided.  Make " \
                              "sure it is written correcty, and try again.")
          end
          ary = @library.select { |book| book.ident == isbn }
          unless ary.empty?
            raise AddError, _("The EAN/ISBN you provided is already used in this library.")
          end
        end
        if (publisher = @entry_publisher.text.strip).empty?
          raise AddError, _("A publisher must be provided.")
        end

        publishing_year = @entry_publish_date.text.to_i
        # TODO: Get rid of this silly requirement
        if (edition = @entry_edition.text.strip).empty?
          raise AddError, _("A binding must be provided.")
        end

        authors = []
        @treeview_authors.model.each { |_m, _p, i| authors << i[0] }
        if authors.empty?
          raise AddError, _("At least one author must be " \
                               "provided.")
        end
        book = Book.new(title, authors, isbn, publisher,
                        publishing_year.zero? ? nil : publishing_year,
                        edition)
        book.rating = @current_rating
        book.notes = @textview_notes.buffer.text
        book.loaned = @checkbutton_loaned.active?
        book.loaned_to = @entry_loaned_to.text
        # book.loaned_since = Time.at(@date_loaned_since.time)
        book.loaned_since = parse_date(@date_loaned_since.text)
        book.redd = @checkbutton_redd.active?
        book.own = @checkbutton_own.active?
        book.want = @checkbutton_want.active?
        book.tags = @entry_tags.text.split
        @library << book
        @library.save(book)
        if File.exist?(TMP_COVER_FILE) && !@delete_cover_file
          FileUtils.cp(TMP_COVER_FILE, @library.cover(book))
        end
        @on_add_cb.call(book)
        @book_properties_dialog.destroy
      rescue AddError => ex
        ErrorDialog.new(@book_properties_dialog, _("Couldn't add the book"),
                        ex.message).display
      end

      # COPIED from book_properties_dialog_base
      def parse_date(datestring)
        date_format = "%d/%m/%Y"
        begin
          d = Date.strptime(datestring, date_format)
          Time.gm(d.year, d.month, d.day)
        rescue StandardError
          nil
        end
      end

      def on_help
        Alexandria::UI.display_help(@preferences_dialog, "add-book-manually")
      end
    end
  end
end
