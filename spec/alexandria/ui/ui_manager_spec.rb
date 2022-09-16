# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::UI::UIManager do
  let(:main_app) { instance_double(Alexandria::UI::MainApp) }

  it "works" do
    expect { described_class.new main_app }.not_to raise_error
  end

  describe "#on_new" do
    it "works" do
      ui = described_class.new main_app
      libraries = ui.instance_variable_get(:@libraries)
      libraries_count = libraries.all_libraries.count
      ui.on_new
      expect(libraries.all_libraries.count).to eq libraries_count + 1
    end
  end

  describe "#on_books_selection_changed" do
    let(:lib_version) { File.join(LIBDIR, "0.6.2") }
    let(:ui) { described_class.new main_app }
    let(:libraries) { ui.instance_variable_get(:@libraries) }
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

      # This triggers the #on_books_selection_changed callback
      ui.select_a_book regular_library.first

      aggregate_failures do
        expect(ui.model.iter_n_children).to eq regular_library.count
        expect(ui.iconview.selected_items).not_to be_empty
      end
    end
  end

  describe "#select_a_book" do
    let(:ui) { described_class.new main_app }
    let(:libraries) { ui.instance_variable_get(:@libraries) }
    let(:filter_entry) { ui.instance_variable_get(:@filter_entry) }
    let(:regular_library) { libraries.all_regular_libraries.last }

    before do
      lib_version = File.join(LIBDIR, "0.6.2")
      FileUtils.cp_r(lib_version, TESTDIR)

      ui.select_a_library regular_library
      # Make books appear in the view
      regular_library.each { |book| ui.append_book book }
    end

    context "when selecting in the icon view" do
      before do
        # Make view model re-appear
        ui.iconview.unfreeze
      end

      it "selects book if it is in view" do
        ui.select_a_book regular_library.first

        selected = ui.iconview.selected_items
        expect(selected.count).to eq 1
      end

      it "selects nothing if book is not in view due to a filter" do
        filter_entry.text = regular_library.last.title
        ui.filtered_model.refilter

        ui.select_a_book regular_library.first

        selected = ui.iconview.selected_items
        expect(selected.count).to eq 0
      end
    end

    context "when selecting in the list view" do
      before do
        # Make view model re-appear
        ui.listview.unfreeze
      end

      it "selects book if it is in view" do
        ui.select_a_book regular_library.first

        selected, _model = ui.listview.selection.selected_rows
        expect(selected.count).to eq 1
      end

      it "selects nothing if book is not in view due to a filter" do
        filter_entry.text = regular_library.last.title
        ui.filtered_model.refilter

        ui.select_a_book regular_library.first

        selected = ui.listview.selection.to_a
        expect(selected).to be_empty
      end

      it "selects nothing if a new book is not in view due to a filter" do
        filter_entry.text = regular_library.last.title
        ui.filtered_model.refilter

        book = an_artist_of_the_floating_world
        ui.append_book book
        ui.select_a_book book

        selected = ui.listview.selection.to_a
        expect(selected).to be_empty
      end
    end
  end
end
