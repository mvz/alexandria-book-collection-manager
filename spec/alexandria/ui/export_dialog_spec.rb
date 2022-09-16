# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::UI::ExportDialog do
  let(:parent) { Gtk::Window.new :toplevel }
  let(:library) { Alexandria::Library.new "Bar Library" }
  let(:sort_order) { Alexandria::LibrarySortOrder::Unsorted.new }

  it "works" do
    expect { described_class.new parent, library, sort_order }.not_to raise_error
  end

  describe "#perform" do
    let(:export_dialog) { described_class.new parent, library, sort_order }
    let(:chooser) { export_dialog.dialog }

    it "works when response is cancel" do
      allow(chooser).to receive(:run).and_return(Gtk::ResponseType::CANCEL)
      expect { export_dialog.perform }.not_to raise_error
    end

    it "works when response is OK" do
      dir = Dir.mktmpdir
      allow(chooser).to receive(:run).and_return(Gtk::ResponseType::OK)
      allow(chooser).to receive(:filename).and_return File.join(dir, "export")
      expect { export_dialog.perform }.not_to raise_error
    ensure
      FileUtils.remove_entry dir
    end
  end
end
