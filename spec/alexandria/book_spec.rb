# frozen_string_literal: true

# Copyright (C) 2007 Joseph Method
# Copyright (C) 2011, 2015 Matijs van Zuijlen
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

require "spec_helper"

describe Alexandria::Book do
  it "is a thing" do
    expect(an_artist_of_the_floating_world).to be_a described_class
  end

  it "establishes equality only with books with the same identity" do
    book = an_artist_of_the_floating_world
    same_book = an_artist_of_the_floating_world
    different_book = an_artist_of_the_floating_world
    different_book.isbn = "9780571147999"
    aggregate_failures do
      expect(same_book).to eq book
      expect(different_book).not_to eq book
    end
  end

  describe "#rating" do
    let(:book) { an_artist_of_the_floating_world }

    it "returns 0 by default" do
      expect(book.rating).to eq 0
    end
  end

  describe "#rating=" do
    let(:book) { an_artist_of_the_floating_world }

    it "assigns rating" do
      book.rating = 5
      expect(book.rating).to eq 5
    end

    it "does not allow higher rating than 5 to be assigned" do
      expect { book.rating = 6 }.to raise_error ArgumentError
    end

    it "does not allow lower rating than 0 to be assigned" do
      expect { book.rating = -1 }.to raise_error ArgumentError
    end
  end
end
