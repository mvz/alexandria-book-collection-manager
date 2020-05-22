# frozen_string_literal: true

# Copyright (C) 2004-2006 Laurent Sansonetti
# Copyright (C) 2008 Joseph Method
# Copyright (C) 2015, 2016 Matijs van Zuijlen
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

require "alexandria/ui/columns"
require "alexandria/ui/iconview_tooltips"

module Alexandria
  module UI
    class IconViewManager
      ICON_WIDTH = 60
      include Logging
      include GetText
      include DragAndDropable
      def initialize(_iconview, parent)
        @parent = parent
        @iconview = @parent.iconview
        @tooltips = IconViewTooltips.new(@iconview)
        @iconview_model = @parent.iconview_model
        @filtered_model = @parent.filtered_model
        @actiongroup = @parent.actiongroup
        setup_books_iconview
      end

      def setup_books_iconview
        log.info { "setup_books_iconview #{@iconview_model.inspect}" }
        @iconview.model = @iconview_model
        log.info { "now @iconview.model = #{@iconview.model.inspect}" }
        @iconview.selection_mode = :multiple
        @iconview.text_column = Columns::TITLE_REDUCED
        @iconview.pixbuf_column = Columns::COVER_ICON
        @iconview.item_orientation = :vertical
        @iconview.row_spacing = 4
        @iconview.column_spacing = 16
        @iconview.item_width = ICON_WIDTH + 16

        @iconview.signal_connect("selection-changed") do
          log.debug { "selection-changed" }
          @parent.on_books_selection_changed
        end

        @iconview.signal_connect("item-activated") do
          log.debug { "item-activated" }
          @actiongroup["Properties"].activate
          false
        end

        # DND support for Gtk::IconView is shipped since GTK+ 2.8.0.
        setup_view_source_dnd(@iconview) if @iconview.respond_to?(:enable_model_drag_source)
      end

      ICONS_SORTS = [
        Columns::TITLE, Columns::AUTHORS, Columns::ISBN,
        Columns::PUBLISHER, Columns::EDITION, Columns::RATING,
        Columns::REDD, Columns::OWN, Columns::WANT
      ].freeze

      def setup_books_iconview_sorting
        mode = ICONS_SORTS[@prefs.arrange_icons_mode]
        sort = @prefs.reverse_icons ? Gtk::SORT_DESCENDING : Gtk::SORT_ASCENDING
        @iconview_model.set_sort_column_id(mode, sort)
        @filtered_model.refilter # force redraw
      end
    end
  end
end
