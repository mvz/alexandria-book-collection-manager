# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::UI::ConfirmEraseDialog do
  let(:parent) { Gtk::Window.new :toplevel }

  it "can be instantiated" do
    expect { described_class.new parent, "foo-file" }.not_to raise_error
  end

  describe "erase?" do
    let(:instance) { described_class.new parent, "foo-file" }
    let(:dialog) { instance.dialog }

    it "returns false when response is cancel" do
      allow(dialog).to receive(:run).and_return(Gtk::ResponseType::CANCEL)
      expect(instance.erase?).to be false
    end

    it "returns true when response is OK" do
      allow(dialog).to receive(:run).and_return(Gtk::ResponseType::OK)
      expect(instance.erase?).to be true
    end
  end
end
