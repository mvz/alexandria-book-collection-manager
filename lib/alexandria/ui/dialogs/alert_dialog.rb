# Copyright (C) 2004-2006 Laurent Sansonetti
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

# HIG compliant error dialog boxes
module Alexandria
  module UI
    class AlertDialog < Gtk::Dialog
      def initialize(parent, title, stock_icon, buttons, message=nil)
        super("", parent, Gtk::Dialog::DESTROY_WITH_PARENT, *buttons)

        self.border_width = 6
        self.resizable = false
        self.has_separator = false
        self.vbox.spacing = 12

        hbox = Gtk::HBox.new(false, 12)
        hbox.border_width = 6
        self.vbox.pack_start(hbox)

        image = Gtk::Image.new(stock_icon,
                               Gtk::IconSize::DIALOG)
        image.set_alignment(0.5, 0)
        hbox.pack_start(image)

        vbox = Gtk::VBox.new(false, 6)
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
      def initialize(parent, title, message=nil)
        super(parent, title, Gtk::Stock::DIALOG_ERROR,
              [[Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK]], message)
        self.default_response = Gtk::Dialog::RESPONSE_OK
        show_all and run
        destroy
      end
    end
  end
end
