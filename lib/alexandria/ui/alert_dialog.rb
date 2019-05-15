# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

# HIG compliant error dialog boxes
module Alexandria
  module UI
    class AlertDialog < SimpleDelegator
      def initialize(parent, title, stock_icon, buttons, message = nil)
        dialog = Gtk::Dialog.new(title: '', parent: parent, flags: :destroy_with_parent, buttons: buttons)
        super(dialog)

        self.border_width = 6
        self.resizable = false
        child.spacing = 12

        hbox = Gtk::Box.new(:horizontal, 12)
        hbox.homogeneous = false
        hbox.border_width = 6
        child.pack_start(hbox)

        image = Gtk::Image.new(stock: stock_icon,
                               size: Gtk::IconSize::DIALOG)
        image.set_alignment(0.5, 0)
        hbox.pack_start(image)

        vbox = Gtk::Box.new(:vertical, 6)
        vbox.homogeneous = false
        hbox.pack_start(vbox)

        label = Gtk::Label.new
        label.set_alignment(0, 0)
        label.wrap = label.selectable = true
        label.markup = "<b><big>#{title}</big></b>"
        vbox.pack_start(label)

        if message
          label = Gtk::Label.new
          label.set_alignment(0, 0)
          label.wrap = label.selectable = true
          label.markup = message.strip
          vbox.pack_start(label)
        end
      end
    end

    class ErrorDialog < AlertDialog
      def initialize(parent, title, message = nil)
        super(parent, title, Gtk::Stock::DIALOG_ERROR,
              [[Gtk::Stock::OK, :ok]], message)
        # FIXME: Should accept just :ok
        self.default_response = Gtk::ResponseType::OK
      end

      def display
        show_all && run
        destroy
      end
    end
  end
end
