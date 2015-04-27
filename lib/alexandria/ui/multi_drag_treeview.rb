# Copyright (C) 2004-2006 Laurent Sansonetti
# Copyright (C) 2011 Matijs van Zuijlen
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

class Gdk::Event
  def ==(obj)
    obj.is_a?(self.class) and time == obj.time and x == obj.x and y == obj.y and button == obj.button
  end
end

class Gtk::TreeView
  # include Alexandria::Logging

  class Context < Struct.new(:pressed_button,
                             :x,
                             :y,
                             :cell_x,
                             :cell_y,
                             :button_press_handler,
                             :motion_notify_handler,
                             :button_release_handler,
                             :drag_data_get_handler,
                             :events,
                             :source_start_button_mask,
                             :source_targets,
                             :source_actions,
                             :pending_event,
                             :drag_context)

    def initialize(*ary)
      super
      self.events ||= []
    end

    def pending_event?
      pending_event
    end
  end

  alias_method :old_enable_model_drag_source, :enable_model_drag_source
  def enable_model_drag_source(start_button_mask, targets, actions)
    old_enable_model_drag_source(start_button_mask, targets, actions)

    @context = Context.new
    @context.source_start_button_mask = start_button_mask
    @context.source_targets = Gtk::TargetList.new(targets)
    @context.source_actions = actions

    @context.button_press_handler =
      signal_connect('button_press_event') do |_widget, event, _data|
        button_press_event(event)
      end
  end

  def drag_context
    @context.drag_context
  end

  private

  def stop_drag_check
    raise if @context.nil?
    @context.events.clear
    @context.pending_event = false
    signal_handler_disconnect(@context.motion_notify_handler)
    signal_handler_disconnect(@context.button_release_handler)
  end

  def button_release_event(_event)
    @context.events.each { |evnt| Gtk.propagate_event(self, evnt) }
    stop_drag_check
    false
  end

  def motion_notify_event(event)
    if Gtk::Drag.threshold?(self, @context.x, @context.y, event.x, event.y)
      stop_drag_check
      paths = []
      selection.selected_each { |_model, path, _iter| paths << path }
      @context.drag_context = Gtk::Drag.begin(self,
                                              @context.source_targets,
                                              @context.source_actions,
                                              @context.pressed_button,
                                              event)
    end
    true
  end

  def button_press_event(event)
    return false if event.button == 3
    return false if event.window != bin_window
    return false if @context.events.include?(event)

    if @context.pending_event?
      @context.events << event
      return true
    end

    return false if event.event_type == Gdk::Event::BUTTON2_PRESS

    path, _, cell_x, cell_y = get_path_at_pos(event.x, event.y)
    return false if path.nil?

    # call_parent = (event.state.control_mask? or event.state.shift_mask?) or !selected or event.button != 1
    call_parent = !selection.path_is_selected?(path) or
      event.button != 1

    if call_parent
      signal_handler_block(@context.button_press_handler) do
        signal_emit('button_press_event', event)
      end
    end

    if selection.path_is_selected?(path)
      @context.pending_event = true
      @context.pressed_button = event.button
      @context.x = event.x
      @context.y = event.y
      @context.cell_x = cell_x
      @context.cell_y = cell_y
      @context.motion_notify_handler =
        signal_connect('motion_notify_event') do |_widget, evnt, _data|
          motion_notify_event(evnt)
        end
      @context.button_release_handler =
        signal_connect('button_release_event') do |_widget, evnt, _data|
          button_release_event(evnt)
        end
      @context.events << event unless call_parent
    end

    true
  end
end
