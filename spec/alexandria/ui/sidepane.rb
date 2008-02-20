# Copyright (C) 2008 Joseph Method
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

require File.dirname(__FILE__) + '/../../spec_helper'

describe Alexandria::UI::SidePaneManager do
  it "should work" do
    selection = mock(Gtk::SelectionMode, :signal_connect => nil)

    library_listview, parent = mock(Gtk::TreeView, :model= => nil, :append_column => nil, :set_row_separator_func => nil, :selection => selection, :enable_model_drag_dest => nil, :signal_connect => nil), mock(Object)
    Alexandria::UI::SidePaneManager.new library_listview, parent
  end
end
