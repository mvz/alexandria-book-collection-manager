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
    class BookPropertiesDialogBase < GladeBase
      include GetText
      extend GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

      COVER_MAXWIDTH = 140    # pixels

      def initialize(parent, cover_file)
        super('book_properties_dialog.glade')
        @book_properties_dialog.transient_for = parent
        @parent, @cover_file = parent, cover_file

        @entry_title.complete_titles
        @entry_title.grab_focus
        @entry_publisher.complete_publishers
        @entry_edition.complete_editions
        @entry_loaned_to.complete_borrowers

        @treeview_authors.model = Gtk::ListStore.new(String, TrueClass)
        @treeview_authors.selection.mode = Gtk::SELECTION_SINGLE
        renderer = Gtk::CellRendererText.new
        renderer.signal_connect('edited') do |cell, path_string, new_text|
          path = Gtk::TreePath.new(path_string)
          iter = @treeview_authors.model.get_iter(path)
          iter[0] = new_text
        end
        renderer.signal_connect('editing_started') do |cell, entry,
          path_string|
          entry.complete_authors
        end
        col = Gtk::TreeViewColumn.new("", renderer,
                                      :text => 0,
                                      :editable => 1)
        @treeview_authors.append_column(col)
      end

      def on_title_changed
        title = @entry_title.text.strip
        @book_properties_dialog.title = unless title.empty?
                                          _("Properties for '%s'") % title
                                        else
                                          _("Properties")
                                        end
      end

      def on_add_author
        iter = @treeview_authors.model.append
        iter[0] = _("Author")
        iter[1] = true
        @treeview_authors.set_cursor(iter.path,
                                     @treeview_authors.get_column(0),
                                     true)
      end

      def on_remove_author
        if iter = @treeview_authors.selection.selected
          @treeview_authors.model.remove(iter)
        end
      end

      def on_image_rating1_press
        self.rating = 1
      end

      def on_image_rating2_press
        self.rating = 2
      end

      def on_image_rating3_press
        self.rating = 3
      end

      def on_image_rating4_press
        self.rating = 4
      end

      def on_image_rating5_press
        self.rating = 5
      end

      def on_image_no_rating_press
        self.rating = 0
      end

      def redd_toggled
      end

      def own_toggled
        if @checkbutton_own.active?
          @checkbutton_want.inconsistent = true
        else
          @checkbutton_want.inconsistent = false
        end
      end

      def want_toggled
      end

      @@latest_filechooser_directory = ENV['HOME']
      def on_change_cover
        backend = `uname`.chomp == "FreeBSD" ? "neant" : "gnome-vfs"
        dialog = Gtk::FileChooserDialog.new(_("Select a cover image"),
                                            @book_properties_dialog,
                                            Gtk::FileChooser::ACTION_OPEN,
                                            backend,
                                            [_("No Cover"),
                                             Gtk::Dialog::RESPONSE_REJECT],
                                            [Gtk::Stock::CANCEL,
                                             Gtk::Dialog::RESPONSE_CANCEL],
                                            [Gtk::Stock::OPEN,
                                             Gtk::Dialog::RESPONSE_ACCEPT])
        dialog.current_folder = @@latest_filechooser_directory
        response = dialog.run
        if response == Gtk::Dialog::RESPONSE_ACCEPT
          begin
            cover = Gdk::Pixbuf.new(dialog.filename)
            # At this stage the file format is recognized.
            FileUtils.cp(dialog.filename, @cover_file)
            self.cover = cover
            @@latest_filechooser_directory = dialog.current_folder
          rescue RuntimeError => e
            ErrorDialog.new(@book_properties_dialog, e.message)
          end
        elsif response == Gtk::Dialog::RESPONSE_REJECT
          FileUtils.rm_f(@cover_file)
          self.cover = Icons::BOOK_ICON
        end
        dialog.destroy
      end

      def on_destroy; end     # no action by default

      def on_loaned
        loaned = @checkbutton_loaned.active?
        @entry_loaned_to.sensitive = loaned
        @date_loaned_since.sensitive = loaned
        @label_loaning_duration.visible = loaned
      end

      def on_loaned_date_changed
        loaned_time = Time.at(@date_loaned_since.time)
        n_days = ((Time.now - loaned_time) / (3600*24)).to_i
        @label_loaning_duration.label = if n_days > 0
                                          n_("%d day", "%d days", n_days) % n_days
                                        else
                                          ""
                                        end
      end

      #######
      private
      #######

      def rating=(rating)
        images = [
                  @image_rating1,
                  @image_rating2,
                  @image_rating3,
                  @image_rating4,
                  @image_rating5
                 ]
        raise "out of range" if rating < 0 or rating > images.length
        images[0..rating-1].each { |x| x.pixbuf = Icons::STAR_SET }
        images[rating..-1].each { |x| x.pixbuf = Icons::STAR_UNSET }
        @current_rating = rating
      end

      def cover=(pixbuf)
        if pixbuf.width > COVER_MAXWIDTH
          new_height = pixbuf.height / (pixbuf.width / COVER_MAXWIDTH.to_f)
          # We don't want to modify in place the given pixbuf,
          # that's why we make a copy.
          pixbuf = pixbuf.scale(COVER_MAXWIDTH, new_height)
        end
        @image_cover.pixbuf = pixbuf
      end

      def loaned_since=(time)
        @date_loaned_since.time = time.tv_sec
        # XXX 'date_changed' signal not automatically called after #time=.
        on_loaned_date_changed
      end

    end
  end
end
