# Copyright (C) 2007 kksou
# Copyright (C) 2008 Cathal Mc Ginley
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


# Please retain the following note:
#
# Based upon Recipe 168 - "How to display tooltips in GtkTreeView - Part 3"
# from the "php-gtk2 Cookbook" website, by kksou.
# http://www.kksou.com/php-gtk2/articles/display-tooltips-in-GtkTreeView---Part-3---no-hardcoding-of-header-height.php
#
# Ported to ruby-gtk2 (and modified for IconView) by Cathal Mc Ginley

class IconViewTooltips
  def initialize(view)
    @tooltip_window = Gtk::Window.new(Gtk::Window::POPUP)
    @tooltip_window.name = 'gtk-tooltips'
    @tooltip_window.resizable = false
    @tooltip_window.border_width = 4
    @tooltip_window.app_paintable = true

    @tooltip_window.signal_connect('expose_event') { |window, event|
      on_expose(window, event) }

    @label = Gtk::Label.new('')
    @label.wrap = true
    @label.set_alignment(0.5, 0.5)
    @label.use_markup = true
    @label.show()

    @tooltip_window.add(@label)
    set_view(view)
  end

  def set_view(view)
    view.signal_connect('motion_notify_event') { |view, event|
      on_motion(view, event) }
    view.signal_connect('leave_notify_event') { |view, event|
      on_leave(view, event) }
  end

  def on_expose(window, event)
    # this paints a nice outline around the label
    size = window.size_request
    window.style.paint_flat_box(window.window,
                                Gtk::STATE_NORMAL,
                                Gtk::SHADOW_OUT,
                                nil,
                                @tooltip_window,
                                'tooltip',
                                0,0,size[0],size[1])
    # must return nil so the label contents get drawn correctly
    nil
  end

  def on_motion(view, event)
    tree_path = view.get_path(event.x, event.y)
    # TODO translate path a few times, for sorting & filtering...
    if tree_path
      iter = view.model.get_iter(tree_path)
      if @latest_iter == nil
        @latest_iter = iter

        @tooltip_timeout_id = Gtk.timeout_add(250) do
          if @latest_iter == iter

            title = iter[2] # HACK hardcoded, should use column names...
            authors = iter[4]
            publisher = iter[6]
            year = iter[7]
            @label.markup = "<b>#{title}</b>\n<i>#{authors}</i>\n<small>#{publisher} <i>(#{year})</i></small>"
            size = @tooltip_window.size_request
            @tooltip_window.move(event.x_root - size[0],
                                 event.y_root + 12)
            @tooltip_window.show()
            # don't run again
            false
          else
            false
            @tooltip_timeout_id = nil
          end
        end

      elsif @latest_iter != iter
        hide_tooltip()
      end


    else
      hide_tooltip()
    end
  end

  def hide_tooltip()
    @tooltip_window.hide()
    if @tooltip_timeout_id
      Gtk.timeout_remove(@tooltip_timeout_id)
      @tooltip_timeout_id = nil
    end
    @latest_iter = nil
  end
  
  def on_leave(view, event)
    @tooltip_window.hide()
  end
end
