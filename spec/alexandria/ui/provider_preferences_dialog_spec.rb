# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::UI::ProviderPreferencesDialog do
  let(:parent) { Gtk::Window.new :toplevel }
  let(:variable) do
    instance_double(Alexandria::BookProviders::Preferences::Variable,
                    name: "foo-bar", description: "Foo Bar", possible_values: nil,
                    value: "baz", mandatory?: false)
  end
  let(:preferences) do
    instance_double(Alexandria::BookProviders::Preferences, length: 0, read: [variable])
  end
  let(:provider) do
    instance_double(Alexandria::BookProviders::GenericProvider,
                    fullname: "FooProvider",
                    prefs: preferences)
  end

  it "can be instantiated" do
    obj = described_class.new parent, provider
    expect(obj).to be_a described_class

    # NOTE: Dialog must be destroyed to avoid a TypeError after the spec run
    # (visible when running ruby in debug mode).
    # TODO: Delay initialization of the dialog until needed in #acquire
    obj.destroy
  end

  describe "#acquire" do
    let(:preferences_dialog) { described_class.new parent, provider }

    before do
      allow(preferences_dialog.dialog).to receive(:run)
      allow(variable).to receive(:new_value=)
    end

    it "runs the underlying Gtk+ dialog" do
      preferences_dialog.acquire

      expect(preferences_dialog.dialog).to have_received(:run)
    end

    it "updates variables" do
      preferences_dialog.acquire

      expect(variable).to have_received(:new_value=).with "baz"
    end
  end
end
