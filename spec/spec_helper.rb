# Copyright (C) 2007 Joseph Method
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

$:.unshift(File.join(File.dirname(__FILE__), '/../lib'))

require  'alexandria'

LIBDIR = File.expand_path(File.join(File.dirname(__FILE__), '/data/libraries'))
TESTDIR = File.join(LIBDIR, 'test')



#def useTestLibrary(version)
#  libVersion = File.join(LIBDIR, version)
#  FileUtils.cp_r(libVersion, TESTDIR)
#end

def an_artist_of_the_floating_world
  Alexandria::Book.new("An Artist of the Floating World",
                       "Kazuo Ishiguro",
                       "9780571147168",
                       "Faber and Faber", 1999,
                       "Paperback")
end

Thread.new { Alexandria::UI::start_gnome_program }
Alexandria::UI::Icons.init

# find a nicer way to do this... it generates a warning at the moment
module Alexandria
  class Library
    DIR = TESTDIR
  end
end

