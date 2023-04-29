# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::Scanners::KeyboardWedge do
  let(:scanner) { described_class.new }
  let(:partials) do
    ["9",
     "978057507",
     "97805711471"]
  end
  let(:scans) do
    {
      isbn: "978 05711 47168",
      ib5: "978057 5079038 007 99"
    }
  end

  it "is called KeyboardWedge" do
    expect(scanner.name).to match(/KeyboardWedge/i)
  end

  it "refuses to detect incomplete scans" do
    aggregate_failures do
      partials.each { |scan| expect(scanner.match?(scan)).to be false }
    end
  end

  it "detects complete scans" do
    aggregate_failures do
      expect(scanner.match?(scans[:isbn])).to be true
      expect(scanner.match?(scans[:ib5])).to be true
    end
  end

  it "decodes ISBN barcodes" do
    expect(scanner.decode(scans[:isbn])).to eq("9780571147168")
  end

  it "decodes ISBN+5 barcodes" do
    expect(scanner.decode(scans[:ib5])).to eq("9780575079038") # 00799
  end
end
