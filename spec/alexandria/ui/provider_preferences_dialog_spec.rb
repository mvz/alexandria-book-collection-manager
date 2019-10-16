# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require File.dirname(__FILE__) + '/../../spec_helper'

describe Alexandria::UI::ProviderPreferencesDialog do
  it 'works' do
    parent = Gtk::Window.new :toplevel
    preferences = instance_double(Alexandria::BookProviders::Preferences,
                                  length: 0, read: [])
    provider = instance_double(Alexandria::BookProviders::GenericProvider,
                               fullname: 'FooProvider',
                               prefs: preferences)
    described_class.new parent, provider
  end
end
