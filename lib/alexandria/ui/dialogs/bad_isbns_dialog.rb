# Copyright (C) 2007 Joseph Method
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
    # Generalized Dialog for lists of bad isbns. Used for on_import. Can also
    # be used for on_load library conversions.
    class BadIsbnsDialog < Gtk::MessageDialog
      def initialize(parent, message=nil, list = nil)
        message = _("There's a problem" ) unless message
        super(parent, Gtk::Dialog::MODAL, Gtk::MessageDialog::WARNING,  Gtk::MessageDialog::BUTTONS_CLOSE, message)
        isbn_container = Gtk::HBox.new
        the_vbox = self.children.first
        the_vbox.pack_start(isbn_container)
        the_vbox.reorder_child(isbn_container, 3)
        scrolley = Gtk::ScrolledWindow.new
        isbn_container.pack_start(scrolley)
        textview = Gtk::TextView.new(Gtk::TextBuffer.new)
        textview.editable = false
        textview.cursor_visible = false
        scrolley.add(textview)
        list.each do |li|
          textview.buffer.insert_at_cursor("#{li}\n")
        end
        show_all
      end
    end
  end
end
