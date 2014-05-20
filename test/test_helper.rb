#!/usr/bin/env ruby
# Copyright (C) 2011, 2014 Matijs van Zuijlen
# Incorporates code Copyright (C) 2007 Joseph Method
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

require 'minitest/autorun'

require 'gettext'
require 'alexandria'

LIBDIR = File.expand_path(File.join(File.dirname(__FILE__), '/data/libraries'))
TESTDIR = File.join(LIBDIR, 'test')

def an_artist_of_the_floating_world
  Alexandria::Book.new("An Artist of the Floating World",
                       "Kazuo Ishiguro",
                       "9780571147168",
                       "Faber and Faber", 1999,
                       "Paperback")
end

# find a nicer way to do this... it generates a warning at the moment
module Alexandria
  class Library
    DIR = TESTDIR
  end
end

