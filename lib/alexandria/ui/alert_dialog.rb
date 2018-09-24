# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "cgi/escape"

module Alexandria
  module UI
    class AlertDialog
      def initialize(parent, title, stock_icon, buttons, message = nil)
        @dialog = Gtk::Dialog.new
        @dialog.title = ""
        @dialog.destroy_with_parent = true
        @dialog.parent = parent
        buttons.each do |button_text, response_id|
          @dialog.add_button button_text, response_id
        end

        @dialog.border_width = 6
        @dialog.resizable = false
        @dialog.content_area.spacing = 12

        hbox = Gtk::Box.new(:horizontal, 12)
        hbox.homogeneous = false
        hbox.border_width = 6

        image = Gtk::Image.new_from_icon_name(stock_icon, :dialog)
        image.set_alignment(0.5, 0)
        hbox.pack_start(image, false, false, 0)

        vbox = Gtk::Box.new(:vertical, 6)
        vbox.homogeneous = false
        vbox.pack_start(make_label("<b><big>#{title}</big></b>"), false, false, 0)
        if message
          vbox.pack_start(make_label(CGI.escapeHTML(message.strip)), false, false, 0)
        end
        hbox.pack_start(vbox, false, false, 0)

        @dialog.child.pack_start(hbox, false, false, 0)
      end

      attr_reader :dialog

      def show_all
        dialog.show_all
      end

      def run
        dialog.run
      end

      def destroy
        dialog.destroy
      end

      def set_default_response(response)
        dialog.set_default_response response
      end

      private

      def make_label(markup)
        label = Gtk::Label.new
        label.set_alignment(0, 0)
        label.wrap = label.selectable = true
        label.markup = markup
        label
      end
    end
  end
end
