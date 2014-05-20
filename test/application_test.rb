#!/usr/bin/env ruby
# Copyright (C) 2005-2006 Laurent Sansonetti
# Copyright (C) 2011, 2014 Matijs van Zuijlen
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

class TestAlexandriaApplication < MiniTest::Test
  def test_application_runs
    Alexandria::UI::Icons.init
    @main_app = Alexandria::UI::MainApp.instance

    Gtk.timeout_add(100) do
      @main_app.main_app.destroy
      Gtk.main_quit
    end

    Gtk.main
  end
end
