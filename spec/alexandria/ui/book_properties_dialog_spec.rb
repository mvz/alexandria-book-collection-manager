# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::UI::BookPropertiesDialog do
  let(:parent) { Gtk::Window.new :toplevel }
  let(:library) do
    store = Alexandria::LibraryCollection.instance.library_store
    store.load_library("Bar Library")
  end
  let(:book) do
    Alexandria::Book.new("Foo Book", ["Jane Doe"], "98765432", "Bar Publisher",
                         1972, "edition")
  end

  before do
    library << book
  end

  it "can be instantiated" do
    obj = described_class.new parent, library, book
    expect(obj).to be_a described_class

    # NOTE: Dialog must be destroyed to avoid a TypeError after the spec run
    # (visible when running ruby in debug mode).
    obj.destroy
  end

  describe "#on_change_cover" do
    let(:dialog) { described_class.new parent, library, book }
    let(:filechooser) { instance_double(Gtk::FileChooserDialog).as_null_object }

    before do
      allow(Gtk::FileChooserDialog).to receive(:new).and_return(filechooser)
      allow(filechooser).to receive(:filename)
        .and_return File.join(__dir__, "../../fixtures/cover.jpg")
    end

    it "works when response is accept" do
      allow(filechooser)
        .to receive(:run).and_return(Gtk::ResponseType::ACCEPT)

      expect { dialog.on_change_cover }.not_to raise_error
    end

    it "works when response is reject" do
      allow(filechooser)
        .to receive(:run).and_return(Gtk::ResponseType::REJECT)

      expect { dialog.on_change_cover }.not_to raise_error
    end

    it "works when response is cancel" do
      allow(filechooser)
        .to receive(:run).and_return(Gtk::ResponseType::CANCEL)

      expect { dialog.on_change_cover }.not_to raise_error
    end
  end
end
