# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::UI::AcquireDialog do
  let(:parent) { Gtk::Window.new :toplevel }
  let(:library) { Alexandria::Library.new("Hi") }
  let(:ui_manager) { instance_double(Alexandria::UI::UIManager) }

  it "can be instantiated" do
    allow(ui_manager).to receive :set_status_label
    dialog = described_class.new parent, ui_manager, library
    expect(dialog).to be_a described_class

    # NOTE: Dialog must be destroyed to avoid a TypeError after the spec run
    # (visible when running ruby in debug mode).
    dialog.acquire_dialog.destroy
  end
end
