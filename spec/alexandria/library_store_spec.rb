# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "spec_helper"

RSpec.describe Alexandria::LibraryStore do
  let(:loader) { described_class.new(TESTDIR) }

  describe "#load_all_smart_libraries" do
    context "when none exist" do
      it "creates and saves some" do
        smart_libs = loader.load_all_smart_libraries
        aggregate_failures do
          expect(smart_libs.size).to eq 5
          smart_libs.each do |lib|
            expect(lib.yaml).to be_an_existing_file
          end
        end
      end
    end

    context "when one exists" do
      it "returns the existing smart library" do
        existing = Alexandria::SmartLibrary.new("Hi", [], :all, loader)
        existing.save
        smart_libs = loader.load_all_smart_libraries
        aggregate_failures do
          expect(smart_libs.size).to eq 1
          expect(smart_libs.first.yaml).to eq existing.yaml
        end
      end
    end
  end
end
