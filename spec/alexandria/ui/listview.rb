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


describe Alexandria::UI::ListViewManager do
  it "should work" do
    model = mock(Object)
    prefs = mock(Object)
    selection = mock(Gtk::SelectionMode, :mode= => nil, :signal_connect => nil)
    treeview = mock(Gtk::TreeView, :model= => model, :append_column => nil, :selection => selection, :signal_connect => nil, :signal_connect_after => nil)
    treeview.should_receive(:enable_model_drag_source)
    listview, parent = treeview, mock(Object, :prefs => mock(Object))
    Alexandria::UI::ListViewManager.new(listview, parent)
  end
end
