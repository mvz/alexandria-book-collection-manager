# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "alexandria/ui/builder_base"
require "alexandria/ui/error_dialog"

module Alexandria
  module UI
    class BookPropertiesDialogBase < BuilderBase
      include GetText
      extend GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

      COVER_MAXWIDTH = 140 # pixels

      COVER_ABSOLUTE_MAXHEIGHT = 250 # pixels, above this we scale down...

      def initialize(parent, cover_file)
        super("book_properties_dialog__builder.glade", widget_names)
        @setup_finished = false
        @book_properties_dialog.transient_for = parent
        @parent = parent
        @cover_file = cover_file
        @original_cover_file = nil
        @delete_cover_file = false # fixing bug #16707

        @entry_title.complete_titles
        @entry_title.grab_focus
        @entry_publisher.complete_publishers
        @entry_edition.complete_editions
        @entry_loaned_to.complete_borrowers

        @entry_tags.complete_tags

        @treeview_authors.model = Gtk::ListStore.new(String, TrueClass)
        @treeview_authors.selection.mode = :single
        renderer = Gtk::CellRendererText.new
        renderer.signal_connect("edited") do |_cell, path_string, new_text|
          path = Gtk::TreePath.new(path_string)
          iter = @treeview_authors.model.get_iter(path)
          iter[0] = new_text
        end
        renderer.signal_connect("editing_started") do |_cell, entry, _path_string|
          entry.complete_authors
        end
        col = Gtk::TreeViewColumn.new("", renderer,
                                      text: 0,
                                      editable: 1)
        @treeview_authors.append_column(col)

        setup_calendar_widgets
        GLib::Timeout.add(150) do
          @setup_finished = true

          false
        end
      end

      def setup_calendar_widgets
        @popup_displayed = false
        @calendar_popup = Gtk::Window.new # Gtk::Window::POPUP)
        # @calendar_popup.modal = true
        @calendar_popup.decorated = false
        @calendar_popup.skip_taskbar_hint = true
        @calendar_popup.skip_pager_hint = true
        @calendar_popup.events = [:focus_change_mask]

        @calendar_popup.set_transient_for(@book_properties_dialog)
        @calendar_popup.set_type_hint :dialog
        @calendar_popup.name = "calendar-popup"
        @calendar_popup.resizable = false
        # @calendar_popup.border_width = 4
        # @calendar_popup.app_paintable = true

        @calendar_popup.signal_connect("focus-out-event") do |_popup, _event|
          hide_calendar_popup
          false
        end

        @calendar = Gtk::Calendar.new
        @calendar_popup.add(@calendar)

        @calendar.signal_connect("day-selected") do
          date_arr = @calendar.date
          year = date_arr[0]
          month = date_arr[1] # + 1 # gtk : months 0-indexed, Time.gm : 1-index
          day = date_arr[2]
          if @calendar_popup_for_entry
            time = Time.gm(year, month, day)
            @calendar_popup_for_entry.text = format_date(time)
          end
        end

        @calendar.signal_connect("day-selected-double-click") do
          date_arr = @calendar.date
          year = date_arr[0]
          month = date_arr[1] # + 1 # gtk : months 0-indexed, Time.gm : 1-index
          day = date_arr[2]
          if @calendar_popup_for_entry
            time = Time.gm(year, month, day)
            @calendar_popup_for_entry.text = format_date(time)
          end
          hide_calendar_popup
        end

        @redd_date.signal_connect("icon-press") do |entry, primary, _icon|
          if primary.nick == "primary"
            display_calendar_popup(entry)
          elsif primary.nick == "secondary"
            clear_date_entry(entry)
          end
        end

        @date_loaned_since.signal_connect("icon-press") do |entry, primary, _icon|
          if primary.nick == "primary"
            display_calendar_popup(entry)
          elsif primary.nick == "secondary"
            clear_date_entry(entry)
            @label_loaning_duration.label = ""
          end
        end
      end

      def clear_date_entry(entry)
        entry.text = ""
      end

      def hide_calendar_popup
        @calendar_popup_for_entry = nil

        @calendar_popup.hide_all
        @book_properties_dialog.modal = true

        GLib::Timeout.add(150) do
          # If we set @popup_displayed=false immediately, then a click
          # event on the primary icon of the Entry simultaneous with
          # the focus-out-event of the Calendar causes the Calendar to
          # pop up again milliseconds after being closed.
          #
          # This is never what the user intends.
          #
          # So we add a small delay before the primary icon's event
          # handler is told to pop up the calendar in response to
          # clicks.

          @popup_displayed = false
          false
        end
      end

      def display_calendar_popup(entry)
        if @popup_displayed
          hide_calendar_popup
        else
          @calendar_popup_for_entry = entry
          unless entry.text.strip.empty?
            time = parse_date(entry.text)
            unless time.nil?
              @calendar.year = time.year
              @calendar.month = time.month - 1
              @calendar.day = time.day
            end
          end
          @book_properties_dialog.modal = false
          @calendar_popup.move(*get_entry_popup_coords(entry))
          @calendar_popup.show_all
          @popup_displayed = true
        end
      end

      def get_entry_popup_coords(entry)
        gdk_win = entry.parent_window
        x, y = gdk_win.origin
        alloc = entry.allocation
        x += alloc.x
        y += alloc.y
        y += alloc.height
        # x = [0, x].max
        # y = [0, y].max
        [x, y]
      end

      def widget_names
        [:book_properties_dialog, :button_box, :button_cover,
         :checkbutton_loaned, :checkbutton_own, :checkbutton_redd,
         :checkbutton_want, :date_loaned_since, :entry_edition,
         :entry_loaned_to, :entry_publish_date, :entry_publisher, :entry_isbn,
         :entry_tags, :entry_title, :image_cover, :image_rating1,
         :image_rating2, :image_rating3, :image_rating4, :image_rating5,
         :label_loaning_duration, :notebook, :redd_date, :textview_notes,
         :treeview_authors]
      end

      def on_title_changed
        title = @entry_title.text.strip
        @book_properties_dialog.title = if title.empty?
                                          _("Properties")
                                        else
                                          _("Properties for '%s'") % title
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
        iter = @treeview_authors.selection.selected
        @treeview_authors.model.remove(iter) if iter
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

      def own_toggled
        @checkbutton_want.inconsistent = if @checkbutton_own.active?
                                           true
                                         else
                                           false
                                         end
      end

      def want_toggled; end

      @@latest_filechooser_directory = ENV["HOME"]
      def on_change_cover
        backend = `uname`.chomp == "FreeBSD" ? "neant" : "gnome-vfs"
        dialog = Gtk::FileChooserDialog.new(_("Select a cover image"),
                                            @book_properties_dialog,
                                            Gtk::FileChooser::ACTION_OPEN,
                                            backend,
                                            [_("No Cover"), Gtk::ResponseType::REJECT],
                                            [Gtk::Stock::CANCEL, Gtk::ResponseType::CANCEL],
                                            [Gtk::Stock::OPEN, Gtk::ResponseType::ACCEPT])
        dialog.current_folder = @@latest_filechooser_directory
        response = dialog.run
        if response == Gtk::ResponseType::ACCEPT
          begin
            @delete_cover_file = false
            cover = GdkPixbuf::Pixbuf.new(file: dialog.filename)
            # At this stage the file format is recognized.

            if File.exist?(@cover_file)
              unless @original_cover_file
                # make a back up, but only of the original
                @original_cover_file = "#{@cover_file}~"
                FileUtils.cp(@cover_file, @original_cover_file)
              end
            end
            if cover.height > COVER_ABSOLUTE_MAXHEIGHT
              FileUtils.cp(dialog.filename, "#{@cover_file}.orig")
              new_width = cover.width / (cover.height / COVER_ABSOLUTE_MAXHEIGHT.to_f)
              log.info do
                "Scaling large cover image to" \
                  " #{new_width.to_i} x #{COVER_ABSOLUTE_MAXHEIGHT}"
              end
              cover = cover.scale(new_width.to_i, COVER_ABSOLUTE_MAXHEIGHT)
              cover.save(@cover_file, "jpeg")
            else
              FileUtils.cp(dialog.filename, @cover_file)
            end

            self.cover = cover
            @@latest_filechooser_directory = dialog.current_folder
          rescue RuntimeError => ex
            ErrorDialog.new(@book_properties_dialog, ex.message).display
          end
        elsif response == Gtk::ResponseType::REJECT
          ## FileUtils.rm_f(@cover_file) # fixing bug #16707
          @delete_cover_file = true

          self.cover = Icons::BOOK_ICON
        end
        dialog.destroy
      end

      def on_destroy
        @book_properties_dialog.hide
        # Stop notebook trying to set tab labels at this time
        @notebook.show_tabs = false
      end

      def on_loaned
        loaned = @checkbutton_loaned.active?
        @entry_loaned_to.sensitive = loaned
        @date_loaned_since.sensitive = loaned
        @label_loaning_duration.visible = loaned
      end

      def on_loaned_date_changed
        date_regexes =  [%r{[0123]?[0-9]/[0123]?[0-9]/[0-9]{4}},
                         /[0-9]{4}-[0123]?[0-9]-[0123]?[0-9]/]
        matches_regex = false
        date_regexes.each do |regex|
          matches_regex = regex.match(@date_loaned_since.text)
          break if matches_regex
        end
        return unless matches_regex

        t = parse_date(@date_loaned_since.text)
        if t.nil?
          @label_loaning_duration.label = ""
          return
        end
        loaned_time = Time.at(t)
        n_days = ((Time.now - loaned_time) / (3600 * 24)).to_i
        if n_days > 365_250 # 1,000 years
          @label_loaning_duration.label = ""
          return
        end
        @label_loaning_duration.label = if n_days > 0
                                          n_("%d day", "%d days", n_days) % n_days
                                        else
                                          ""
                                        end
      end

      def redd_toggled
        redd_yes = @checkbutton_redd.active?
        @redd_date.sensitive = redd_yes
        if @setup_finished
          # don't do this when popping up the dialog for the first time
          display_calendar_popup(@redd_date) if redd_yes && @redd_date.text.strip.empty?
        end
      end

      private

      def rating=(rating)
        images = [
          @image_rating1,
          @image_rating2,
          @image_rating3,
          @image_rating4,
          @image_rating5
        ]
        raise _("out of range") if rating < 0 || rating > images.length

        images[0..rating - 1].each { |x| x.pixbuf = Icons::STAR_SET }
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
        if time.nil?
          @date_loaned_since.text = ""
          @label_loaning_duration.label = ""
        else
          @date_loaned_since.text = format_date(time)
          on_loaned_date_changed
        end
        # XXX 'date_changed' signal not automatically called after #time=.
      end

      def redd_when=(time)
        @redd_date.text = format_date(time)
      end

      def parse_date(datestring)
        # '%m/%d/%Y' for USA and Canada ; or '%Y-%m-%d' for most of Asia
        # http://en.wikipedia.org/wiki/Calendar_date#Middle_endian_forms.2C_starting_with_the_month
        date_format = "%d/%m/%Y"
        begin
          d = Date.strptime(datestring, date_format)
          Time.gm(d.year, d.month, d.day)
        rescue StandardError
          nil
        end
      end

      def format_date(datetime)
        datetime.strftime("%d/%m/%Y")
      end
    end
  end
end
