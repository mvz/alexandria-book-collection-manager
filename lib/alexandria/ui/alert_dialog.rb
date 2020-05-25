# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

module Alexandria
  module UI
    class AlertDialog
      def initialize(parent, title, stock_icon, buttons, message = nil)
        @dialog = Gtk::Dialog.new(title: "", parent: parent, flags: :destroy_with_parent,
                                  buttons: buttons)
        @dialog.border_width = 6
        @dialog.resizable = false
        @dialog.child.spacing = 12

        hbox = Gtk::Box.new(:horizontal, 12)
        hbox.homogeneous = false
        hbox.border_width = 6

        image = Gtk::Image.new(stock: stock_icon,
                               size: Gtk::IconSize::DIALOG)
        image.set_alignment(0.5, 0)
        hbox.pack_start(image)

        vbox = Gtk::Box.new(:vertical, 6)
        vbox.homogeneous = false
        vbox.pack_start make_label("<b><big>#{title}</big></b>")
        vbox.pack_start make_label(message.strip) unless message
        hbox.pack_start(vbox)

        @dialog.child.pack_start(hbox)
      end

      def show_all
        dialog.show_all
      end

      def run
        dialog.run
      end

      def destroy
        dialog.destroy
      end

      def default_response=(response)
        dialog.default_response = response
      end

      private

      attr_reader :dialog

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
