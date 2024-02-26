# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

module Gtk
  load_class :TreeView
end

module Alexandria
  module EventOverrides
    def ==(other)
      other.is_a?(self.class) &&
        (time == other.time) && (x == other.x) && (y == other.y) &&
        (button == other.button)
    end
  end

  module TreeViewOverrides
    Context = Struct.new(:pressed_button,
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

    class Context
      def initialize(*ary)
        super
        self.events ||= []
      end

      def pending_event?
        pending_event
      end
    end

    # FIXME: Don't override this method.
    # FIXME: Re-enable or re-implement
    def xx_enable_model_drag_source(start_button_mask, targets, actions)
      super

      @context = Context.new
      @context.source_start_button_mask = start_button_mask
      @context.source_targets = Gtk::TargetList.new(entries)
      @context.source_actions = actions

      @context.button_press_handler =
        signal_connect("button-press-event") do |_widget, event, _data|
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
      if drag_check_threshold(@context.x, @context.y, event.x, event.y)
        stop_drag_check
        paths = []
        selection.selected_each { |_model, path, _iter| paths << path }
        @context.drag_context = drag_begin(@context.source_targets,
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

      (call_parent = !selection.path_is_selected(path)) ||
        (event.button != 1)

      if call_parent
        signal_handler_block(@context.button_press_handler) do
          signal_emit("button_press_event", event)
        end
      end

      if selection.path_is_selected(path)
        @context.pending_event = true
        @context.pressed_button = event.button
        @context.x = event.x
        @context.y = event.y
        @context.cell_x = cell_x
        @context.cell_y = cell_y
        @context.motion_notify_handler =
          signal_connect("motion-notify-event") do |_widget, evnt, _data|
            motion_notify_event(evnt)
          end
        @context.button_release_handler =
          signal_connect("button-release-event") do |_widget, evnt, _data|
            button_release_event(evnt)
          end
        @context.events << event unless call_parent
      end

      true
    end
  end
end

Gdk::Event.prepend Alexandria::EventOverrides
Gtk::TreeView.prepend Alexandria::TreeViewOverrides
