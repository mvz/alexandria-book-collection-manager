require File.dirname(__FILE__) + '/../../spec_helper'

describe Alexandria::UI::SidePaneManager do
  it "should work" do
    selection = mock(Gtk::SelectionMode, :signal_connect => nil)
    
    library_listview, parent = mock(Gtk::TreeView, :model= => nil, :append_column => nil, :set_row_separator_func => nil, :selection => selection, :enable_model_drag_dest => nil, :signal_connect => nil), mock(Object)
    Alexandria::UI::SidePaneManager.new library_listview, parent 
  end
end
