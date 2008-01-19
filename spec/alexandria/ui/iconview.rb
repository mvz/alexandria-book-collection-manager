require File.dirname(__FILE__) + '/../../spec_helper'

describe Alexandria::UI::IconViewManager do
  it "should work" do
    iconview, parent = mock(Object), mock(Object)
    iconview_man = Alexandria::UI::IconViewManager.new iconview, parent
  end
end
