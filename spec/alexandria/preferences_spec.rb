# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../spec_helper"

describe Alexandria::Preferences do
  let(:instance) { described_class.instance }

  describe "#get_variable" do
    it "returns nil fetching unknown setting" do
      expect(instance.get_variable("does_not_exist")).to eq nil
    end

    it "allows fetching by string" do
      instance.toolbar_visible = false
      expect(instance.get_variable("toolbar_visible")).to eq false
    end

    it "allows fetching by symbol" do
      instance.toolbar_visible = true
      expect(instance.get_variable(:toolbar_visible)).to eq true
    end
  end

  describe "#set_variable" do
    it "allows setting by string" do
      instance.toolbar_visible = false
      instance.set_variable("toolbar_visible", true)
      expect(instance.toolbar_visible).to eq true
    end

    it "allows setting by symbol" do
      instance.toolbar_visible = false
      instance.set_variable(:toolbar_visible, true)
      expect(instance.toolbar_visible).to eq true
    end
  end

  it "allows setting known setting to false" do
    instance.toolbar_visible = false
    expect(instance.toolbar_visible).to eq false
  end

  it "resets known setting by setting to nil" do
    instance.toolbar_visible = nil
    expect(instance.toolbar_visible).to eq true
  end
end
