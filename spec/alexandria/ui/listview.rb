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
