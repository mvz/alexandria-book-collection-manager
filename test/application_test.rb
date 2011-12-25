#!/usr/bin/env ruby
# Copyright (C) 2005-2006 Laurent Sansonetti
# Modifications Copyright (C) 2011 Matijs van Zuijlen
#
# This file is part of Alexandria, a GNOME book collection manager.
#
# Alexandria is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# Alexandria is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with Alexandria; see the file COPYING.  If not,
# write to the Free Software Foundation, Inc., 51 Franklin Street,
# Fifth Floor, Boston, MA 02110-1301 USA.

require File.expand_path('test_helper.rb', File.dirname(__FILE__))

ENV['http_proxy'] = nil if !ENV['http_proxy'].nil? \
and URI.parse(ENV['http_proxy']).userinfo.nil?

$KCODE = "U"

class TestAlexandriaApplication < Test::Unit::TestCase

  def __test_application
    Alexandria::UI::Icons.init
    @main_app = Alexandria::UI::MainApp.instance

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
