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

#require 'alexandria/ui/glade_base'

module Alexandria
  module UI
    class BookPropertiesDialogBase < BuilderBase
      include GetText
      extend GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")

      COVER_MAXWIDTH = 140    # pixels

      COVER_ABSOLUTE_MAXHEIGHT = 250 # pixels, above this we scale down...

      def initialize(parent, cover_file)
        super('book_properties_dialog__builder.glade', widget_names)
        @setup_finished = false
        @book_properties_dialog.transient_for = parent
        @parent, @cover_file = parent, cover_file
        @original_cover_file = nil
        @delete_cover_file = false # fixing bug #16707

        @entry_title.complete_titles
        @entry_title.grab_focus
        @entry_publisher.complete_publishers
        @entry_edition.complete_editions
        @entry_loaned_to.complete_borrowers

        @entry_tags.complete_tags

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

        setup_calendar_widgets
        Gtk.timeout_add(150) do
          @setup_finished = true
          
          false
        end
      end

      def setup_calendar_widgets
        @popup_displayed = false
        @calendar_popup = Gtk::Window.new()# Gtk::Window::POPUP)
        # @calendar_popup.modal = true
        @calendar_popup.decorated = false
        @calendar_popup.skip_taskbar_hint = true
        @calendar_popup.skip_pager_hint = true
        @calendar_popup.events = [Gdk::Event::FOCUS_CHANGE_MASK]
        
        @calendar_popup.set_transient_for(@book_properties_dialog )
        @calendar_popup.set_type_hint( Gdk::Window::TYPE_HINT_DIALOG )
        @calendar_popup.name = 'calendar-popup'
        @calendar_popup.resizable = false
        # @calendar_popup.border_width = 4
        # @calendar_popup.app_paintable = true

        @calendar_popup.signal_connect("focus-out-event") do |popup, event|
          hide_calendar_popup
          false
        end

        @calendar = Gtk::Calendar.new
        @calendar_popup.add(@calendar)

        @calendar.signal_connect("day-selected") do
          date_arr = @calendar.date
          year = date_arr[0]
          month = date_arr[1]# + 1 # gtk : months 0-indexed, Time.gm : 1-index
          day = date_arr[2]
          if @calendar_popup_for_entry
            time = Time.gm(year, month, day)
            @calendar_popup_for_entry.text = format_date(time)
          end

        end
        
        @calendar.signal_connect("day-selected-double-click") do
          date_arr = @calendar.date
          year = date_arr[0]
          month = date_arr[1]# + 1 # gtk : months 0-indexed, Time.gm : 1-index
          day = date_arr[2]
          if @calendar_popup_for_entry
            time = Time.gm(year, month, day)
            @calendar_popup_for_entry.text = format_date(time)
          end
          hide_calendar_popup
        end

        @redd_date.signal_connect('icon-press') do |entry, primary, icon|
          if primary.nick == 'primary'
            display_calendar_popup(entry)
          elsif primary.nick == 'secondary'
            clear_date_entry(entry)
          end
        end

        @date_loaned_since.signal_connect('icon-press') do |entry, primary, icon|
          if primary.nick == 'primary'
            display_calendar_popup(entry)
          elsif primary.nick == 'secondary'
            clear_date_entry(entry)
            @label_loaning_duration.label = ""
          end                                               
        end

      end

      def clear_date_entry(entry)
        entry.text = ''
      end

      def hide_calendar_popup
        @calendar_popup_for_entry = nil

        @calendar_popup.hide_all
        @book_properties_dialog.modal = true

        Gtk.timeout_add(150) do

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
        x,y = gdk_win.origin
        alloc = entry.allocation
        x += alloc.x
        y += alloc.y
        y += alloc.height
        #x = [0, x].max
        #y = [0, y].max
        [x, y]
      end

      def widget_names
        [:book_properties_dialog, :dialog_vbox1, :button_box,
         :notebook1, :hbox1, :table1, :label1, :label7, :entry_title,
         :entry_publisher, :label5, :entry_isbn, :hbox3,
         :scrolledwindow2, :treeview_authors, :vbox2, :button3,
         :image2, :button4, :image3, :label3, :label9, :entry_edition,
         :label16, :entry_publish_date, :label17, :entry_tags,
         :vseparator1, :vbox1, :label12, :button_cover, :image_cover,
         :vbox4, :vbox5, :checkbutton_own, :vbox6, :checkbutton_redd,
         :redd_date, :checkbutton_want, :eventbox8, :hbox2,
         :eventbox6, :image5, :eventbox1, :image_rating1, :eventbox5,
         :image_rating2, :eventbox4, :image_rating3, :eventbox3,
         :image_rating4, :eventbox2, :image_rating5, :eventbox7,
         :image4, :label11, :label9, :vbox3, :checkbutton_loaned,
         :table2, :entry_loaned_to, :label_loaning_duration, :label15,
         :label14, :date_loaned_since, :label13, :scrolledwindow1,
         :textview_notes, :label10]
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
            @delete_cover_file = false
            cover = Gdk::Pixbuf.new(dialog.filename)
            # At this stage the file format is recognized.
            
            if File.exists?(@cover_file)
              unless @original_cover_file
                # make a back up, but only of the original
                @original_cover_file = "#{@cover_file}~"
                FileUtils.cp(@cover_file, @original_cover_file)
              end
            end
            if cover.height > COVER_ABSOLUTE_MAXHEIGHT
              FileUtils.cp(dialog.filename, "#{@cover_file}.orig")
              new_width = cover.width / (cover.height / COVER_ABSOLUTE_MAXHEIGHT.to_f)
              puts "Scaling large cover image to #{new_width.to_i} x #{COVER_ABSOLUTE_MAXHEIGHT}"
              cover = cover.scale(new_width.to_i, COVER_ABSOLUTE_MAXHEIGHT)
              cover.save(@cover_file, "jpeg")
            else
              FileUtils.cp(dialog.filename, @cover_file)              
            end


            self.cover = cover
            @@latest_filechooser_directory = dialog.current_folder
          rescue RuntimeError => e
            ErrorDialog.new(@book_properties_dialog, e.message)
          end
        elsif response == Gtk::Dialog::RESPONSE_REJECT
          ## FileUtils.rm_f(@cover_file) # fixing bug #16707
          @delete_cover_file = true

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
        date_regexes =  [/[0123]?[0-9]\/[0123]?[0-9]\/[0-9]{4}/,
                        /[0-9]{4}-[0123]?[0-9]-[0123]?[0-9]/]
        matches_regex = false
        date_regexes.each do |regex|
          if matches_regex = regex.match(@date_loaned_since.text)
            break
          end
        end
        unless matches_regex
          return
        end
        t = parse_date(@date_loaned_since.text)
        if t.nil?
          @label_loaning_duration.label = ""
          return
        end
        loaned_time = Time.at(t)
        n_days = ((Time.now - loaned_time) / (3600*24)).to_i
        if n_days > 365250 # 1,000 years
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
	redd_yes=@checkbutton_redd.active?
	@redd_date.sensitive=redd_yes
        if @setup_finished
          # don't do this when popping up the dialog for the first time
          if redd_yes && @redd_date.text.strip.empty?
            display_calendar_popup(@redd_date)
          end
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
        date_format = '%d/%m/%Y' # or '%m/%d/%Y' for USA and Canada ; or '%Y-%m-%d' for most of Asia
        ## http://en.wikipedia.org/wiki/Calendar_date#Middle_endian_forms.2C_starting_with_the_month
        begin
          d = Date.strptime(datestring, date_format)          
          Time.gm(d.year, d.month, d.day)
        rescue => er
          nil
        end
      end

      def format_date(datetime)
         date_format = '%d/%m/%Y'
        datetime.strftime( date_format = '%d/%m/%Y')
      end

    end
  end
end
