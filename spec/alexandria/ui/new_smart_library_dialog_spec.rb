# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::UI::NewSmartLibraryDialog do
  let(:parent) { Gtk::Window.new :toplevel }

  it "can be instantiated" do
    obj = described_class.new parent
    expect(obj).to be_a described_class

    # NOTE: Dialog must be destroyed to avoid a TypeError after the spec run
    # (visible when running ruby in debug mode).
    obj.destroy
  end

  describe "#acquire" do
    let(:properties_dialog) { described_class.new parent }
    let(:gtk_dialog) { properties_dialog.dialog }
    let(:rules_box) { properties_dialog.instance_variable_get(:@rules_box) }
    let(:rule_entry) { rules_box.children.first.children[2] }

    it "works when response is cancel" do
      allow(gtk_dialog).to receive(:run).and_return(Gtk::ResponseType::CANCEL)
      expect { properties_dialog.acquire }.not_to raise_error
    end

    it "returns a smart library that can be saved when response is ok" do
      allow(gtk_dialog).to receive(:run).and_return(Gtk::ResponseType::OK)

      # Make sure entered rule is valid
      rule_entry.text = "foo"

      result = properties_dialog.acquire

      aggregate_failures do
        expect(result).to be_a Alexandria::SmartLibrary
        expect { result.save }.not_to raise_error
      end
    end
  end
end
