# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require File.dirname(__FILE__) + "/../../spec_helper"

describe Alexandria::UI::ImportDialog do
  let(:parent) { Gtk::Window.new :toplevel }

  it "can be instantiated" do
    described_class.new parent
  end

  describe "#acquire" do
    it "works when response is cancel" do
      import_dialog = described_class.new parent
      chooser = import_dialog.dialog
      allow(chooser).to receive(:run).and_return(Gtk::ResponseType::CANCEL)
      import_dialog.acquire
    end
  end
end
