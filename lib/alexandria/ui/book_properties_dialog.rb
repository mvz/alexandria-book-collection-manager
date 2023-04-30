# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "alexandria/ui/error_dialog"

module Alexandria
  module UI
    class BookPropertiesDialog < BookPropertiesDialogBase
      include GetText
      extend GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

      def initialize(parent, library, book)
        super(parent, library.cover(book))
        log.debug { "Initializing Book Properties Dialog" }

        cancel_button = Gtk::Button.new(stock_id: Gtk::Stock::CANCEL)
        cancel_button.signal_connect("clicked") { on_cancel }
        cancel_button.show
        @button_box << cancel_button

        close_button = Gtk::Button.new(stock_id: Gtk::Stock::SAVE)
        close_button.signal_connect("clicked") { on_close }
        close_button.show
        @button_box << close_button

        help_button = Gtk::Button.new(stock_id: Gtk::Stock::HELP)
        help_button.signal_connect("clicked") { on_help }
        help_button.show
        @button_box << help_button
        @button_box.set_child_secondary(help_button, true)

        @entry_title.text = @book_properties_dialog.title = book.title
        @entry_isbn.text = (book.isbn || "")
        @entry_publisher.text = book.publisher
        @entry_publish_date.text = book.publishing_year.to_s
        @entry_publish_date.signal_connect("focus-out-event") do
          text = @entry_publish_date.text
          if text.empty?
            false
          else
            year = text.to_i
            if year.zero? || year > (Time.now.year + 10) || year < 10
              @entry_publish_date.text = ""
              @entry_publish_date.grab_focus
              true
            elsif year < 100
              @entry_publish_date.text = "19" + year.to_s
              false
            end
          end
        end
        @entry_edition.text = book.edition
        if book.tags
          @entry_tags.text = book.tags.join(",") # tags are comma-separated
        end

        book.authors.each do |author|
          iter = @treeview_authors.model.append
          iter[0] = author
          iter[1] = true
        end

        buffer = Gtk::TextBuffer.new
        buffer.text = (book.notes || "")
        @textview_notes.buffer = buffer

        @library = library
        @book = book
        self.cover = Icons.cover(library, book)
        self.rating = (book.rating || Book::DEFAULT_RATING)

        if (@checkbutton_loaned.active = book.loaned?)
          @entry_loaned_to.text = (book.loaned_to || "")
          self.loaned_since = book.loaned_since
          @date_loaned_since.sensitive = true
        else
          @date_loaned_since.sensitive = false
        end

        @checkbutton_own.active = book.own?

        @block_calendar_popup = true
        if book.redd?
          @redd_date.text = format_date(book.redd_when) unless book.redd_when.nil?
          @checkbutton_redd.active = true
        else
          @checkbutton_redd.active = false
        end
        @block_calendar_popup = false

        @checkbutton_want.active = book.want?

        @checkbutton_want.inconsistent = true if (@checkbutton_own.active = book.own?)
      end

      private

      def on_close
        if @entry_isbn.text == ""
          # If set to nil .to_yaml in library.save causes crash
          @book.isbn = ""
        else
          isbn = Library.canonicalise_ean(@entry_isbn.text)
          unless isbn
            ErrorDialog.new(@book_properties_dialog,
                            _("Couldn't modify the book"),
                            _("Couldn't validate the EAN/ISBN you " \
                              "provided.  Make sure it is written " \
                              "correcty, and try again.")).display
            return
          end

          ary = @library.select { |book| book.ident == isbn }
          unless ary.empty? || ((ary.length == 1) && (ary.first == @book))
            ErrorDialog.new(@book_properties_dialog,
                            _("Couldn't modify the book"),
                            _("The EAN/ISBN you provided is already " \
                              "used in this library.")).display
            return
          end

          @book.isbn = isbn
        end
        @book.title = @entry_title.text
        @book.publisher = @entry_publisher.text
        year = @entry_publish_date.text.to_i
        @book.publishing_year = year.zero? ? nil : year
        @book.edition = @entry_edition.text
        @book.authors = []
        @treeview_authors.model.each { |_m, _p, i| @book.authors << i[0] }
        @book.notes = @textview_notes.buffer.text
        @book.rating = @current_rating

        @book.loaned = @checkbutton_loaned.active?
        @book.loaned_to = @entry_loaned_to.text
        loaned_since = @date_loaned_since.text
        if loaned_since.strip.empty?
          @book.loaned_since = nil
        else
          t = parse_date(loaned_since)
          @book.loaned_since = t
        end

        @book.redd = @checkbutton_redd.active?
        if @book.redd
          redd_date = @redd_date.text
          if redd_date.strip.empty?
            @book.redd_when = nil
          else
            t = parse_date(redd_date)
            @book.redd_when = t
          end
        else
          @book.redd_when = nil
        end
        @book.own = @checkbutton_own.active?
        @book.want = @checkbutton_want.active?
        @book.tags = @entry_tags.text.split(",") # tags are comma separated

        FileUtils.rm_f(@cover_file) if @delete_cover_file

        FileUtils.rm_f(@original_cover_file) if @original_cover_file

        @library.save(@book)
        # @on_close_cb.call(@book)
        @book_properties_dialog.destroy
      end

      def on_cancel
        FileUtils.mv(@original_cover_file, @cover_file) if @original_cover_file
        @book_properties_dialog.destroy
      end

      def on_help
        Alexandria::UI.display_help(@preferences_dialog,
                                    "editing-book-properties")
      end
    end
  end
end
