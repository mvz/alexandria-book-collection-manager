# Copyright (C) 2004-2006 Laurent Sansonetti
#
# Alexandria is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# Alexandria is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with Alexandria; see the file COPYING.  If not,
# write to the Free Software Foundation, Inc., 51 Franklin Street,
# Fifth Floor, Boston, MA 02110-1301 USA.

module Alexandria
  module UI
    class BookPropertiesDialog < BookPropertiesDialogBase
      include Logging
      include GetText
      extend GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")

      def initialize(parent, library, book)
        super(parent, library.cover(book))
        puts "Initializing Book Properties Dialog..." if $DEBUG

        cancel_button = Gtk::Button.new(Gtk::Stock::CANCEL)
        cancel_button.signal_connect('clicked') { on_cancel }
        cancel_button.show
        @button_box << cancel_button

        close_button = Gtk::Button.new(Gtk::Stock::SAVE)
        close_button.signal_connect('clicked') { on_close }
        close_button.show
        @button_box << close_button

        help_button = Gtk::Button.new(Gtk::Stock::HELP)
        help_button.signal_connect('clicked') { on_help }
        help_button.show
        @button_box << help_button
        @button_box.set_child_secondary(help_button, true)

        @entry_title.text = @book_properties_dialog.title = book.title
        @entry_isbn.text = (book.isbn or "")
        @entry_publisher.text = book.publisher
        @entry_publish_date.text = (book.publishing_year.to_s \
                                  rescue "")
        @entry_publish_date.signal_connect('focus-out-event') do
          text = @entry_publish_date.text
          unless text.empty?
            year = text.to_i
            if year == 0 or year > (Time.now.year + 10) or year < 10
              @entry_publish_date.text = ""
              @entry_publish_date.grab_focus
              true
            elsif year < 100
              @entry_publish_date.text = "19" + year.to_s
              false
            end
          else
            false
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
        buffer.text = (book.notes or "")
        @textview_notes.buffer = buffer

        @library, @book = library, book
        self.cover = Icons.cover(library, book)
        self.rating = (book.rating or Book::DEFAULT_RATING)

        if @checkbutton_loaned.active = book.loaned?
          @entry_loaned_to.text = (book.loaned_to or "")
          self.loaned_since = book.loaned_since
          @date_loaned_since.sensitive = true
        else
          @date_loaned_since.sensitive = false          
        end

        @checkbutton_own.active = book.own?
        if @checkbutton_redd.active = book.redd?
          @redd_date.sensitive = true
          if book.redd_when.nil?
            puts "no redd_when"
          else
            @redd_date.text = format_date(book.redd_when)
          end
	  #self.redd_when = (book.redd_when or Time.now)
        else
          @redd_date.sensitive = false
	end
        @checkbutton_want.active = book.want?

        if @checkbutton_own.active = book.own?
          @checkbutton_want.inconsistent = true
        end
      end

      #######
      private
      #######

      def on_close
        if @entry_isbn.text == ""
 		  # If set to nil .to_yaml in library.save causes crash
          @book.isbn = ""
        else
          ary = @library.select { |book| book.ident == @entry_isbn.text }
          unless ary.empty? or (ary.length == 1 and ary.first == @book)
            ErrorDialog.new(@parent,
                            _("Couldn't modify the book"),
                            _("The EAN/ISBN you provided is already " +
                              "used in this library."))
            return
          end
          @book.isbn = begin
                         Library.canonicalise_ean(@entry_isbn.text)
                       rescue Alexandria::Library::InvalidISBNError
                         ErrorDialog.new(@parent,
                                         _("Couldn't modify the book"),
                                         _("Couldn't validate the EAN/ISBN you " +
                                           "provided.  Make sure it is written " +
                                           "correcty, and try again."))
                         return
                       end
        end
        @book.title = @entry_title.text
        @book.publisher = @entry_publisher.text
        year = @entry_publish_date.text.to_i
        @book.publishing_year = year == 0 ? nil : year
        @book.edition = @entry_edition.text
        @book.authors = []
        @treeview_authors.model.each { |m, p, i| @book.authors << i[0] }
        @book.notes = @textview_notes.buffer.text
        @book.rating = @current_rating

        @book.loaned = @checkbutton_loaned.active?
        @book.loaned_to = @entry_loaned_to.text
        loaned_since = @date_loaned_since.text
        if loaned_since.strip.empty?
          @book.loaned_since = nil
        else
          begin
            t = parse_date(loaned_since)
            @book.loaned_since = t
          rescue
          end
        end

        @book.redd = @checkbutton_redd.active?
	if @book.redd
          redd_date = @redd_date.text
          if redd_date.strip.empty?
            @book.redd_when = nil
          else
            begin
              t =  parse_date(redd_date)
              @book.redd_when = t
            rescue => err
              puts err
              puts err.backtrace
            end
          end
	else
          @book.redd_when = nil
	end
        @book.own = @checkbutton_own.active?
        @book.want = @checkbutton_want.active?
        @book.tags = @entry_tags.text.split(',') # tags are comma separated


        if @delete_cover_file
          FileUtils.rm_f(@cover_file)
        end        

        if @original_cover_file
          FileUtils.rm_f(@original_cover_file)
        end

        @library.save(@book)
        # @on_close_cb.call(@book)
        @book_properties_dialog.destroy
      end

      def on_cancel
        if @original_cover_file
          FileUtils.mv(@original_cover_file, @cover_file)
        end
        @book_properties_dialog.destroy
      end

      def on_help
        Alexandria::UI::display_help(@preferences_dialog,
                                     'editing-book-properties')
      end
    end
  end
end
