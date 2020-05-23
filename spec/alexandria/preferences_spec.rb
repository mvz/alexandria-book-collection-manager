# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require File.dirname(__FILE__) + "/../spec_helper"

describe Alexandria::Preferences do
  let(:instance) { described_class.instance }

  it "returns nil fetching unknown setting" do
    expect(instance.get_variable("does_not_exist")).to eq nil
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
