# frozen_string_literal: true

# Copyright (C) 2022 Matijs van Zuijlen
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

RSpec.describe Alexandria::PseudoMarcParser do
  describe ".marc_text_to_book" do
    let(:marc_text) do
      <<~MARC
        00991pam  2200289 a 4500
        001 426456
        005 19820209000000.0
        008 811005s1981    maua     b    001 0 eng#{'  '}
        035    $9 (DLC)   81017108
        906    $a 7 $b cbc $c orignew $d 1 $e ocip $f 19 $g y-gencatlg
        010    $a    81017108#{' '}
        020    $a 0805335587
        020    $a 0805335579 (pbk.)
        040    $a DLC $c DLC $d DLC
        050 00 $a QA612 $b .G7
        082 00 $a 514/.2 $2 19
        100 1  $a Greenberg, Marvin J.
        245 10 $a Algebraic topology : $b a first course / $c Marvin J. Greenberg, John R. Harper.
        260    $a Reading, Mass. : $b Benjamin/Cummings Pub. Co., $c 1981.
        300    $a xi, 311 p. : $b ill. ; $c 24 cm.
        440  0 $a Mathematics lecture note series ; $v 58
        500    $a "A revision of the first author's Lectures on algebraic topology"--P.
        504    $a Bibliography: p. 303-307.
        500    $a Includes index.
        650  0 $a Algebraic topology.
        700 1  $a Harper, John R., $d 1941-
        991    $b c-GenColl $h QA612 $i .G7 $p 00035736761 $t Copy 1 $w BOOKS
      MARC
    end

    it "returns a book with the correct attributes" do
      result = described_class.marc_text_to_book(marc_text,
                                                 described_class::USMARC_MAPPINGS)
      aggregate_failures do
        expect(result.title).to eq "Algebraic topology: a first course"
        expect(result.authors).to eq ["Greenberg, Marvin J."]
      end
    end

    it "returns nil when passed a blank string" do
      result = described_class.marc_text_to_book("", described_class::USMARC_MAPPINGS)
      expect(result).to be_nil
    end

    it "returns nil when passed nil" do
      result = described_class.marc_text_to_book(nil, described_class::USMARC_MAPPINGS)
      expect(result).to be_nil
    end
  end
end
