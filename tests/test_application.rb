#!/usr/bin/env ruby
# Copyright (C) 2005-2006 Laurent Sansonetti

require 'test/unit'
require 'gettext'

require 'alexandria'

ENV['http_proxy'] = nil if !ENV['http_proxy'].nil? \
and URI.parse(ENV['http_proxy']).userinfo.nil?

require 'gdk_pixbuf2'
require 'libglade2'
require 'gnome2'

require 'alexandria/ui/icons'
require 'alexandria/ui/glade_base'
require 'alexandria/ui/completion_models'
require 'alexandria/ui/libraries_combo'
require 'alexandria/ui/dialogs/alert_dialog'
require 'alexandria/ui/dialogs/about_dialog'
require 'alexandria/ui/dialogs/book_properties_dialog_base'
require 'alexandria/ui/dialogs/book_properties_dialog'
require 'alexandria/ui/dialogs/new_book_dialog_manual'
require 'alexandria/ui/dialogs/new_book_dialog'
require 'alexandria/ui/dialogs/preferences_dialog'
require 'alexandria/ui/dialogs/export_dialog'
require 'alexandria/ui/dialogs/import_dialog'
require 'alexandria/ui/dialogs/acquire_dialog'
require 'alexandria/ui/dialogs/smart_library_properties_dialog_base'
require 'alexandria/ui/dialogs/smart_library_properties_dialog'
require 'alexandria/ui/dialogs/new_smart_library_dialog'
require 'alexandria/ui/multi_drag_treeview'
require 'alexandria/ui/main_app'
require 'logger'

$KCODE = "U"

class TestAlexandriaApplication < Test::Unit::TestCase

  def __test_application
    Gnome::Program.new('alexandria', VERSION).app_datadir =
      Alexandria::Config::MAIN_DATA_DIR
    Alexandria::UI::Icons.init
    @main_app = Alexandria::UI::MainApp.new

    @thread1 = Thread.new do
      Gtk.main
    end

    #sleep(1)

    assert(@thread1.alive?)

    @main_app_window = @main_app.main_app
    #@main_app_window.hide_all

  end

  def __test_teardown_application
    #I don't understand how to programatically shut down the window!
    #E.g., 'click' the Close Window Button!

    Gtk.main_quit
    sleep(1) #Give it time to shut down
    assert(!@thread1.alive?)
  end

  def test_application_runs
    __test_application

    __test_teardown_application
  end

  def test_import_isbns
    __test_application
    #puts @main_app.pretty_print_instance_variables
    @actiongroup = @main_app.actiongroup
    @appbar = @main_app.appbar
    #puts @actiongroup.pretty_print_instance_variables
    #puts @appbar.pretty_print_instance_variables
    puts @actiongroup.methods
    puts @appbar.methods
    __test_teardown_application
  end
end
