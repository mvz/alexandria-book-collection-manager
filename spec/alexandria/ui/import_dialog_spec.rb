# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::UI::ImportDialog do
  let(:parent) { Gtk::Window.new :toplevel }

  it "can be instantiated" do
    described_class.new parent
  end

  it "handles a selection change" do
    importdialog = described_class.new parent
    importdialog.dialog.signal_emit "selection_changed"
  end

  describe "#acquire" do
    let(:import_dialog) { described_class.new parent }
    let(:chooser) { import_dialog.dialog }

    before do
      allow(chooser).to receive(:filename).and_return("spec/data/isbns.txt")
      allow(Alexandria::BookProviders).to receive(:isbn_search)
        .and_raise Alexandria::BookProviders::SearchEmptyError
      allow(Alexandria::BookProviders).to receive(:isbn_search).with("0595371086")
        .and_return(an_artist_of_the_floating_world)
    end

    it "works when response is cancel" do
      allow(chooser).to receive(:run).and_return(Gtk::ResponseType::CANCEL)
      import_dialog.acquire { nil }
    end

    it "works when response is OK" do
      allow(chooser).to receive(:run).and_return(Gtk::ResponseType::OK)

      result = nil
      import_dialog.acquire { |*args| result = args }
      expect(result.first.to_a).to eq [an_artist_of_the_floating_world]
    end
  end
end
