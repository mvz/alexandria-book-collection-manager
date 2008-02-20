# Copyright (C) 2004-2006 Laurent Sansonetti
# Copyright (C) 2008 Joseph Method
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

require 'alexandria/ui/iconview_tooltips'

module Alexandria
  module UI
    module Columns
      COVER_LIST, COVER_ICON, TITLE, TITLE_REDUCED, AUTHORS,
        ISBN, PUBLISHER, PUBLISH_DATE, EDITION, RATING, IDENT,
        NOTES, REDD, OWN, WANT, TAGS = (0..16).to_a
    end

    class IconViewManager
      ICON_WIDTH = 60
      include Logging
      include GetText
      include DragAndDropable
      def initialize iconview, parent
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
        @iconview.selection_mode = Gtk::SELECTION_MULTIPLE
        @iconview.text_column = Columns::TITLE_REDUCED
        @iconview.pixbuf_column = Columns::COVER_ICON
        @iconview.orientation = Gtk::ORIENTATION_VERTICAL
        @iconview.row_spacing = 4
        @iconview.column_spacing = 16
        @iconview.item_width = ICON_WIDTH + 16

        @iconview.signal_connect('selection-changed') do
          log.debug { "selection-changed" }
          @tooltips.hide_tooltip
          @parent.on_books_selection_changed
        end

        @iconview.signal_connect('item-activated') do
          log.debug { "item-activated" }
          # Dirty hack to avoid the beginning of a drag within this
          # handler.
          @tooltips.hide_tooltip
          Gtk.timeout_add(100) do
            @actiongroup["Properties"].activate
            false
          end
        end

        # DND support for Gtk::IconView is shipped since GTK+ 2.8.0.
        if @iconview.respond_to?(:enable_model_drag_source)
          setup_view_source_dnd(@iconview)
        end
      end

      ICONS_SORTS = [
        Columns::TITLE, Columns::AUTHORS, Columns::ISBN,
        Columns::PUBLISHER, Columns::EDITION, Columns::RATING, Columns::REDD, Columns::OWN, Columns::WANT
      ]
      def setup_books_iconview_sorting
        mode = ICONS_SORTS[@prefs.arrange_icons_mode]
        @iconview_model.set_sort_column_id(mode,
                                           @prefs.reverse_icons \
                                           ? Gtk::SORT_DESCENDING \
                                           : Gtk::SORT_ASCENDING)
        @filtered_model.refilter    # force redraw
      end

    end
  end
end
