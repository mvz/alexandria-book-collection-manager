# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::Scanners::CueCat do
  let(:cuecat) { described_class.new }
  let(:partials) do
    [".",
     ".C3nZC3nZC3n2ChnWENz7DxnY",
     ".C3nZC3nZC3n2ChnWENz7DxnY.",
     ".C3nZC3nZC3n2ChnWENz7DxnY.cGen",
     ".C3nZC3nZC3n2ChnWENz7DxnY.cGen.",
     ".C3nZC3nZC3n2ChnWENz7DxnY.cGen.ENr7C3z0CNj3Dhj1EW"]
  end
  let(:scans) do
    {
      isbn: ".C3nZC3nZC3n2ChnWENz7DxnY.cGen.ENr7C3z0CNj3Dhj1EW.",
      ib5: ".C3nZC3nZC3n2ChnWENz7DxnY.cGf2.ENr7C3z0DNn0ENnWE3nZDhP6."
    }
  end

  it "is called CueCat" do
    expect(cuecat.name).to match(/CueCat/i)
  end

  it "detects a complete scan only" do
    partials.each { |scan| expect(cuecat.match?(scan)).not_to be_truthy }
    expect(cuecat.match?(scans[:isbn])).to be_truthy
    expect(cuecat.match?(scans[:ib5])).to be_truthy
  end

  it "decodes ISBN barcodes" do
    expect(cuecat.decode(scans[:isbn])).to eq("9780571147168")
  end

  it "decodes ISBN+5 barcodes" do
    expect(cuecat.decode(scans[:ib5])).to eq("9780575079038") # 00799
    # TODO are we supposed to keep the +5 bit?
  end

  it "decodes ISSN barcodes" do
    skip "Test scan ISSN"
  end

  it "decodes UPC barcodes" do
    skip "Test scan UPC"
  end
end
