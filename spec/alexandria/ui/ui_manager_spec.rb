# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require File.dirname(__FILE__) + "/../../spec_helper"

describe Alexandria::UI::UIManager do
  it "works" do
    main_app = instance_double(Alexandria::UI::MainApp)
    described_class.new main_app
  end

  describe "#on_new" do
    it "works" do
      main_app = instance_double(Alexandria::UI::MainApp)
      ui = described_class.new main_app
      libraries = ui.instance_variable_get('@libraries')
      libraries_count = libraries.all_libraries.count
      ui.on_new
      expect(libraries.all_libraries.count).to eq libraries_count + 1
    end
  end
end
