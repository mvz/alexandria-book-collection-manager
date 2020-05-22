# frozen_string_literal: true

# Copyright (C) 2004-2006 Laurent Sansonetti
# Copyright (C) 2015, 2016 Matijs van Zuijlen
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

# Ideally this would be a subclass of GtkComboBox, but...

Gtk.load_class :ComboBox

module Alexandria
  module ComboBoxOverrides
    include GetText
    extend GetText
    GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

    def populate_with_libraries(libraries, selected_library)
      libraries_names = libraries.map(&:name)
      if selected_library
        libraries_names.delete selected_library.name
        libraries_names.unshift selected_library.name
      end
      clear
      self.model = Gtk::ListStore.new([GdkPixbuf::Pixbuf.gtype,
                                       GObject::TYPE_STRING,
                                       GObject::TYPE_BOOLEAN])
      libraries_names.each do |library_name|
        append_entry(Alexandria::UI::Icons::LIBRARY_SMALL, library_name, false)
      end
      append_entry(nil, "-", nil)
      append_entry(Alexandria::UI::Icons::LIBRARY_SMALL, _("New Library"), true)
      renderer = Gtk::CellRendererPixbuf.new
      pack_start(renderer, false)
      add_attribute(renderer, "pixbuf", 0)
      renderer = Gtk::CellRendererText.new
      pack_start(renderer, true)
      add_attribute(renderer, "text", 1)
      set_row_separator_func do |model, iter|
        # TODO: Replace with iter[1] if possible
        model.get_value(iter, 1) == "-"
      end
      self.active = 0
      # self.sensitive = libraries.length > 1
      # This prohibits us from adding a "New Library" from this combo
      # when we only have a single library
    end

    def selection_from_libraries(libraries)
      iter = active_iter
      is_new = false
      library = nil
      if iter[2]
        name = Alexandria::Library.generate_new_name(libraries)
        library = Alexandria::Library.load(name)
        libraries << library
        is_new = true
      else
        library = libraries.find do |x|
          x.name == active_iter[1]
        end
      end
      raise unless library

      [library, is_new]
    end

    def append_entry(icon, label, is_new)
      iter = model.append
      model.set_value(iter, 0, icon)
      model.set_value(iter, 1, label)
      model.set_value(iter, 2, is_new)
    end
  end
end

Gtk::ComboBox.prepend Alexandria::ComboBoxOverrides
