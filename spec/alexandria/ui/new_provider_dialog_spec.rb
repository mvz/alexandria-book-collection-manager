# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::UI::NewProviderDialog do
  let(:parent) { Gtk::Window.new :toplevel }

  it "can be instantiated" do
    obj = described_class.new parent
    expect(obj).to be_a described_class

    # NOTE: Dialog must be destroyed to avoid a TypeError after the spec run
    # (visible when running ruby in debug mode).
    # TODO: Delay initialization of the dialog until needed in #acquire
    obj.dialog.destroy
  end

  describe "#acquire" do
    let(:provider_dialog) { described_class.new parent }
    let(:gtk_dialog) { provider_dialog.dialog }

    it "works when response is cancel" do
      allow(gtk_dialog).to receive(:run).and_return(Gtk::ResponseType::CANCEL)
      expect { provider_dialog.acquire }.not_to raise_error
    end

    it "works when response is accept" do
      allow(gtk_dialog).to receive(:run).and_return(Gtk::ResponseType::ACCEPT)
      expect { provider_dialog.acquire }.not_to raise_error
    end
  end
end
