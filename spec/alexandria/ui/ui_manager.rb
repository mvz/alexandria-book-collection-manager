require File.dirname(__FILE__) + '/../../spec_helper'

describe Alexandria::UI::UIManager do
  it "should work" do
    main_app = mock(Object)
    Alexandria::UI::UIManager.new main_app
  end
end
