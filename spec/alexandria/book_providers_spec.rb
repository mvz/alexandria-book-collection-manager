# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "spec_helper"

describe Alexandria::BookProviders do
  describe ".list" do
    before do
      Alexandria::Preferences.instance.set_variable :abstract_providers, []
    end

    it "includes the default set of providers" do
      list = described_class.list
      expect(list.map(&:fullname))
        .to contain_exactly("Thalia (Germany)", "WorldCat", "Library of Congress (Usa)",
                            "British Library", "Servizio Bibliotecario Nazionale (Italy)",
                            "Douban (China)")
    end

    it "includes an added custom provider" do
      instance = described_class.abstract_classes.first.new
      instance.reinitialize("Foo Bar")
      described_class.instance.update_priority

      list = described_class.list
      expect(list.last.fullname).to eq "Foo Bar"
    end
  end
end
