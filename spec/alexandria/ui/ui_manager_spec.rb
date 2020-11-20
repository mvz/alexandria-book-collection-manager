# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::UI::UIManager do
  let(:main_app) { instance_double(Alexandria::UI::MainApp) }

  it "works" do
    described_class.new main_app
  end

  describe "#on_new" do
    it "works" do
      ui = described_class.new main_app
      libraries = ui.instance_variable_get("@libraries")
      libraries_count = libraries.all_libraries.count
      ui.on_new
      expect(libraries.all_libraries.count).to eq libraries_count + 1
    end
  end

  describe "#on_books_selection_changed" do
    let(:lib_version) { File.join(LIBDIR, "0.6.2") }
    let(:ui) { described_class.new main_app }
    let(:libraries) { ui.instance_variable_get("@libraries") }
    let(:regular_library) { libraries.all_regular_libraries.last }

    before do
      FileUtils.cp_r(lib_version, TESTDIR)
    end

    it "works when single book is selected" do
      ui.select_a_library regular_library

      # FIXME: This is needed because right now UIManager#refresh_books doesn't
      # work without Gtk loop.
      regular_library.each { |book| ui.append_book book }
      # This makes the iconview model re-appear
      ui.iconview.unfreeze
      expect(ui.model.iter_n_children).to eq regular_library.count

      # This triggers the #on_books_selection_changed callback
      ui.select_a_book regular_library.first

      expect(ui.iconview.selected_items).not_to be_empty
    end
  end
end
