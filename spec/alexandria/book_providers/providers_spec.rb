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

require File.dirname(__FILE__) + '/../../spec_helper'

describe Alexandria::BookProviders::AdlibrisProvider do
  it "should work"
end

describe Alexandria::BookProviders::BNProvider do
  it "should work"
end

describe Alexandria::BookProviders::BOL_itProvider do
  it "should work"
end

describe Alexandria::BookProviders::DeaStore_itProvider do
  it "should work"
end

describe Alexandria::BookProviders::IBS_itProvider do
  it "should work"
end

describe Alexandria::BookProviders::SicilianoProvider do
  it "should work"
end

describe Alexandria::BookProviders::MCUProvider do
  it "should work"
end

describe Alexandria::BookProviders::ProxisProvider do
  it "should work"
end

describe Alexandria::BookProviders::ThaliaProvider do
  it "should work"
end

describe Alexandria::BookProviders::WorldcatProvider do
  it "should work"
end

if defined? Alexandria::BookProviders::Z3950Provider
  describe Alexandria::BookProviders::Z3950Provider do
    it "should work"
  end

  describe Alexandria::BookProviders::LOCProvider do
    it "should work"
  end

  describe Alexandria::BookProviders::BLProvider do
    it "should work"
  end

  describe Alexandria::BookProviders::SBNProvider do
    it "should work"
  end

  describe Alexandria::BookProviders::SicilianoProvider do
    it "should work"
  end

  describe Alexandria::BookProviders::SicilianoProvider do
    it "should work"
  end
end
