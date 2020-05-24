# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require File.dirname(__FILE__) + "/../../spec_helper"

describe Alexandria::UI::NewSmartLibraryDialog do
  let(:parent) { Gtk::Window.new :toplevel }

  it "can be instantiated" do
    described_class.new parent
  end

  describe "#handle_ok_response" do
    it "returns a smart library" do
      dialog = described_class.new parent
      result = dialog.handle_ok_response

      expect(result).to be_a Alexandria::SmartLibrary
    end
  end
end
