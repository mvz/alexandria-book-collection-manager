#-- -*- ruby -*-
# Copyright (C) 2007 Cathal Mc Ginley
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

$:.unshift(File.join(File.dirname(__FILE__), '../../../lib'))

require  'alexandria/scanners/cuecat'

describe Alexandria::Scanners::CueCat do

  before :all do
    @cuecat = Alexandria::Scanners::CueCat.new
    @partials = ['.',
                 '.C3nZC3nZC3n2ChnWENz7DxnY',
                 '.C3nZC3nZC3n2ChnWENz7DxnY.',
                 '.C3nZC3nZC3n2ChnWENz7DxnY.cGen',
                 '.C3nZC3nZC3n2ChnWENz7DxnY.cGen.',
                 '.C3nZC3nZC3n2ChnWENz7DxnY.cGen.ENr7C3z0CNj3Dhj1EW'
                ]
    @scans = {
      :isbn => '.C3nZC3nZC3n2ChnWENz7DxnY.cGen.ENr7C3z0CNj3Dhj1EW.',
      :ib5 => '.C3nZC3nZC3n2ChnWENz7DxnY.cGf2.ENr7C3z0DNn0ENnWE3nZDhP6.'
    }
  end


  it "is called CueCat" do
    @cuecat.name.should match(/CueCat/i)
  end

  it "should detect a complete scan only " do
    @partials.each { |scan| @cuecat.match?(scan).should_not be_true }
    @cuecat.match?(@scans[:isbn]).should be_true
    @cuecat.match?(@scans[:ib5]).should be_true
  end

  it "should decode ISBN barcodes" do
    @cuecat.decode(@scans[:isbn]).should == '9780571147168'
  end

  it "should decode ISBN+5 barcodes" do
    @cuecat.decode(@scans[:ib5]).should == '9780575079038' # 00799
    # TODO are we supposed to keep the +5 bit?
  end

  it "should decode ISSN barcodes" do
    pending "Test scan ISSN"
  end

  it "should decode UPC barcodes" do
    pending "Test scan UPC"
  end

end
