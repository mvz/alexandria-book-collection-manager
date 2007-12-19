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

require File.dirname(__FILE__) + '/../spec_helper'

describe Alexandria::Book do
  it "should be a thing" do
    an_artist_of_the_floating_world
  end

  it "should establish equality only with books with the same identity" do
    (an_artist_of_the_floating_world == an_artist_of_the_floating_world).should be_true
    different_book = an_artist_of_the_floating_world
    different_book.isbn = "9780571147999"
    (an_artist_of_the_floating_world == different_book).should be_false
  end
end
