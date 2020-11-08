# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::UI::SmartLibraryPropertiesDialog do
  let(:properties_dialog) do
    parent = Gtk::Window.new :toplevel
    loader = Alexandria::LibraryStore.new(TESTDIR)
    smart_library = Alexandria::SmartLibrary.new("Foo", [], :all, loader)
    described_class.new parent, smart_library
  end
  let(:gtk_dialog) { properties_dialog.dialog }

  describe "#acquire" do
    it "works when response is cancel" do
      allow(gtk_dialog).to receive(:run).and_return(Gtk::ResponseType::CANCEL)
      properties_dialog.acquire
    end

    it "works when response is ok" do
      allow(gtk_dialog).to receive(:run).and_return(Gtk::ResponseType::OK)
      properties_dialog.acquire
    end
  end

  describe "#handle_date_icon_press" do
    let(:date_entry) do
      rule_boxes = properties_dialog.handle_add_rule_clicked
      rule_box = rule_boxes.first
      rule_box.children[3]
    end

    before do
      gtk_dialog.show_all
    end

    it "pops up the calendar widget" do
      properties_dialog.handle_date_icon_press(date_entry,
                                               Gtk::EntryIconPosition::PRIMARY,
                                               nil)
      popup = properties_dialog.instance_variable_get(:@calendar_popup)
      expect(popup).to be_visible
    end
  end
end
