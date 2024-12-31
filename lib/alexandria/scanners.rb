# frozen_string_literal: true

# Copyright (C) 2005-2006 Christopher Cyll
# Copyright (C) 2014-2016 Matijs van Zuijlen
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

# Scanners should respond to name(), match?(data), and decode(data).
# They should add an instance of themselves to the Scanner Registry
# on module load.

module Alexandria
  module Scanners
    def self.registry
      @registry ||= []
    end

    def self.register(scanner)
      registry.push(scanner)
    end

    def self.default_scanner
      registry.first
    end

    def self.find_scanner(name)
      registry.find { |scanner| scanner.name == name }
    end

    def self.each_scanner(&)
      registry.each(&)
    end

    private_class_method :registry
  end
end
