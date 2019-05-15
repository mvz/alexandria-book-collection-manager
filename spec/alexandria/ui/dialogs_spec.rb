# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require File.dirname(__FILE__) + '/../../spec_helper'

describe Alexandria::UI::SmartLibraryPropertiesDialog do
  it 'works' do
    parent = Gtk::Window.new :toplevel
    smart_library = instance_double(Alexandria::SmartLibrary,
                                    name: 'Foo',
                                    rules: [],
                                    predicate_operator_rule: :any)
    described_class.new parent, smart_library
  end
end

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

describe Alexandria::UI::NewProviderDialog do
  it 'works' do
    parent = Gtk::Window.new :toplevel
    described_class.new parent
  end
end

describe Alexandria::UI::PreferencesDialog do
  it 'works' do
    parent = Gtk::Window.new :toplevel
    described_class.new(parent) {}
  end
end

describe Alexandria::UI::NewSmartLibraryDialog do
  it 'works' do
    parent = Gtk::Window.new :toplevel
    described_class.new parent
  end
end

describe Alexandria::UI::NewBookDialogManual do
  it 'works' do
    parent = Gtk::Window.new :toplevel
    library = instance_double(Alexandria::Library)
    described_class.new parent, library
  end
end

describe Alexandria::UI::KeepBadISBNDialog do
  it 'works' do
    parent = Gtk::Window.new :toplevel
    book = instance_double(Alexandria::Book,
                           title: 'Foo Book',
                           isbn: '98765432')
    described_class.new parent, book
  end
end

describe Alexandria::UI::ConflictWhileCopyingDialog do
  it 'works' do
    parent = Gtk::Window.new :toplevel
    library = instance_double(Alexandria::Library, name: 'Bar Library')
    book = instance_double(Alexandria::Book, title: 'Foo Book')
    described_class.new parent, library, book
  end
end

describe Alexandria::UI::ReallyDeleteDialog do
  it 'works' do
    library = instance_double(Alexandria::Library, name: 'Bar Library', empty?: false, size: 12)
    parent = Gtk::Window.new :toplevel
    described_class.new parent, library
  end
end

describe Alexandria::UI::SkipEntryDialog do
  it 'works' do
    parent = Gtk::Window.new :toplevel
    described_class.new parent, 'Foo'
  end
end

describe Alexandria::UI::ImportDialog do
  it 'works' do
    parent = Gtk::Window.new :toplevel
    described_class.new parent
  end
end

describe Alexandria::UI::ConfirmEraseDialog do
  it 'works' do
    parent = Gtk::Window.new :toplevel
    described_class.new parent, 'foo-file'
  end
end

describe Alexandria::UI::ExportDialog do
  it 'works' do
    parent = Gtk::Window.new :toplevel
    library = instance_double(Alexandria::Library, name: 'Bar Library')
    described_class.new parent, library, :ascending
  end
end

describe Alexandria::UI::BookPropertiesDialog do
  it 'works' do
    parent = Gtk::Window.new :toplevel
    library = instance_double(Alexandria::Library, name: 'Bar Library', cover: '')
    book = Alexandria::Book.new('Foo Book', ['Jane Doe'], '98765432', 'Bar Publisher',
                                1972, 'edition')
    described_class.new parent, library, book
  end
end

describe Alexandria::UI::BadIsbnsDialog do
  it 'works' do
    parent = Gtk::Window.new :toplevel
    described_class.new parent, 'Careful', []
  end
end

describe Alexandria::UI::ErrorDialog do
  it 'works' do
    parent = Gtk::Window.new :toplevel
    described_class.new parent, 'Boom', 'It went boom'
  end
end

describe Alexandria::UI::AlertDialog do
  it 'works' do
    parent = Gtk::Window.new :toplevel
    described_class.new(parent, 'Hello',
                        Gtk::Stock::DIALOG_QUESTION,
                        [[Gtk::Stock::CANCEL, :cancel]], 'Hi there')
  end
end

describe Alexandria::UI::AcquireDialog do
  it 'works' do
    parent = Gtk::Window.new :toplevel
    described_class.new parent
  end
end

describe Alexandria::UI::AboutDialog do
  it 'works' do
    parent = Gtk::Window.new :toplevel
    described_class.new parent
  end
end
