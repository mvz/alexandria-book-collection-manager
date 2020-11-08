# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

module Alexandria
  module UI
    module CalendarPopup
      def setup_calendar_widgets
        @calendar_popup = Gtk::Popover.new
        @calendar_popup.position = :bottom

        @calendar = Gtk::Calendar.new
        @calendar.show
        @calendar_popup.add(@calendar)

        @calendar.signal_connect("day-selected") do
          assign_selected_date
        end

        @calendar.signal_connect("day-selected-double-click") do
          assign_selected_date
          @calendar_popup.hide
        end
      end

      def assign_selected_date
        date_arr = @calendar.date
        year = date_arr[0]
        month = date_arr[1] # + 1 # gtk : months 0-indexed, Time.gm : 1-index
        day = date_arr[2]
        time = Time.gm(year, month, day)
        @calendar_popup_for_entry.text = format_date(time)
      end

      def clear_date_entry(entry)
        entry.text = ""
      end

      def display_calendar_popup(entry)
        setup_calendar_widgets unless defined? @calendar_popup

        @calendar_popup_for_entry = entry
        unless entry.text.strip.empty?
          time = parse_date(entry.text)
          unless time.nil?
            @calendar.year = time.year
            @calendar.month = time.month - 1
            @calendar.day = time.day
          end
        end
        @calendar_popup.set_relative_to(entry)
        @calendar_popup.popup
      end
    end
  end
end
