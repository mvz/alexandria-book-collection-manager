module Alexandria
  module UI
    BOOKS_TARGET_TABLE = [["ALEXANDRIA_BOOKS",
      Gtk::Drag::TARGET_SAME_APP,
      0]]

    module DragAndDropable
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
