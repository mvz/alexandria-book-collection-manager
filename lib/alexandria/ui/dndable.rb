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

module Alexandria
  module UI
    BOOKS_TARGET_TABLE = [["ALEXANDRIA_BOOKS",
      Gtk::Drag::TARGET_SAME_APP,
      0]]

    module DragAndDropable

      BADGE_MARKUP = "<span weight=\"heavy\" foreground=\"white\">%d</span>"

      def setup_view_source_dnd(view)
        # better be Loggable!
        log.info { "setup_view_source_dnd for %s" % view }
        view.signal_connect_after('drag-begin') do |widget, drag_context|
          n_books = @parent.selected_books.length
          if n_books > 1
            # Render generic book icon.
            pixmap, mask = Icons::BOOK_ICON.render_pixmap_and_mask(255)

            # Create number badge.
            context = Gdk::Pango.context
            layout = Pango::Layout.new(context)
            layout.markup = BADGE_MARKUP % n_books
            width, height = layout.pixel_size
            x = Icons::BOOK_ICON.width - width - 11
            y = Icons::BOOK_ICON.height - height - 11

            # Draw a red ellipse where the badge number should be.
            red_gc = Gdk::GC.new(pixmap)
            red_gc.rgb_fg_color = Gdk::Color.parse('red')
            red_gc.rgb_bg_color = Gdk::Color.parse('red')
            pixmap.draw_arc(red_gc,
                            true,
                            x - 5, y - 2,
                            width + 9, height + 4,
                            0, 360 * 64)

            # Draw the number badge.
            pixmap.draw_layout(Gdk::GC.new(pixmap), x, y, layout)

            # And set the drag icon.
            Gtk::Drag.set_icon(drag_context,
                               pixmap.colormap,
                               pixmap,
                               mask,
                               10,
                               10)
          end
        end

        view.signal_connect('drag-data-get') do |widget, drag_context,
          selection_data, info,
          time|

        idents = @parent.selected_books.map { |book| book.ident }
        unless idents.empty?
          selection_data.set(Gdk::Selection::TYPE_STRING,
                             idents.join(','))
        end
        end

        view.enable_model_drag_source(Gdk::Window::BUTTON1_MASK,
                                      Alexandria::UI::BOOKS_TARGET_TABLE,
                                      Gdk::DragContext::ACTION_MOVE)
      end
    end
  end
end
