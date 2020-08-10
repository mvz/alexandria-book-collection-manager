# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::UI::NewProviderDialog do
  let(:parent) { Gtk::Window.new :toplevel }

  it "can be instantiated" do
    described_class.new parent
  end

  describe "#acquire" do
    let(:provider_dialog) { described_class.new parent }
    let(:gtk_dialog) { provider_dialog.dialog }

    it "works when response is cancel" do
      allow(gtk_dialog).to receive(:run).and_return(Gtk::ResponseType::CANCEL)
      provider_dialog.acquire
    end

    it "works when response is accept" do
      allow(gtk_dialog).to receive(:run).and_return(Gtk::ResponseType::ACCEPT)
      provider_dialog.acquire
    end
  end
end
