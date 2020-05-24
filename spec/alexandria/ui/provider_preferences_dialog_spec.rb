# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require File.dirname(__FILE__) + "/../../spec_helper"

describe Alexandria::UI::ProviderPreferencesDialog do
  let(:parent) { Gtk::Window.new :toplevel }

  it "can be instantiated" do
    preferences = instance_double(Alexandria::BookProviders::Preferences,
                                  length: 0, read: [])
    provider = instance_double(Alexandria::BookProviders::GenericProvider,
                               fullname: "FooProvider",
                               prefs: preferences)
    described_class.new parent, provider
  end

  describe "#acquire" do
    it "works" do
      preferences = instance_double(Alexandria::BookProviders::Preferences,
                                    length: 0, read: [])
      provider = instance_double(Alexandria::BookProviders::GenericProvider,
                                 fullname: "FooProvider",
                                 prefs: preferences)
      preferences_dialog = described_class.new parent, provider
      gtk_dialog = preferences_dialog.dialog
      allow(gtk_dialog).to receive(:run)

      preferences_dialog.acquire
    end
  end
end
