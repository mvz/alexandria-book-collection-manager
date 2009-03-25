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

# Ideally this would be a subclass of GtkComboBox, but...
class Gtk::ComboBox
  include GetText
  extend GetText
  GetText.bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")

  def populate_with_libraries(libraries, selected_library)
    libraries_names = libraries.map { |x| x.name }
    if selected_library
      libraries_names.delete selected_library.name
      libraries_names.unshift selected_library.name
    end
    self.clear
    self.set_row_separator_func do |model, iter|
      iter[1] == '-'
    end
    self.model = Gtk::ListStore.new(Gdk::Pixbuf, String, TrueClass)
    libraries_names.each do |library_name|
      iter = self.model.append
      iter[0] = Alexandria::UI::Icons::LIBRARY_SMALL
      iter[1] = library_name
      iter[2] = false
    end
    self.model.append[1] = '-'
    iter = self.model.append
    iter[0] = Alexandria::UI::Icons::LIBRARY_SMALL
    iter[1] = _('New Library')
    iter[2] = true
    renderer = Gtk::CellRendererPixbuf.new
    self.pack_start(renderer, false)
    self.set_attributes(renderer, :pixbuf => 0)
    renderer = Gtk::CellRendererText.new
    self.pack_start(renderer, true)
    self.set_attributes(renderer, :text => 1)
    self.active = 0
    # self.sensitive = libraries.length > 1 
    # This prohibits us from adding a "New Library" from this combo
    # when we only have a single library
  end

  def selection_from_libraries(libraries)
    iter = self.active_iter
    is_new = false
    library = nil
    if iter[2]
      name = Alexandria::Library.generate_new_name(libraries)
      library = Alexandria::Library.load(name)
      libraries << library
      is_new = true
    else
      library = libraries.find do |x|
        x.name == self.active_iter[1]
      end
    end
    raise unless library
    return [library, is_new]
  end
end
