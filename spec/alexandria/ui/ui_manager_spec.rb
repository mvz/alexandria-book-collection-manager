# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require File.dirname(__FILE__) + '/../../spec_helper'

describe Alexandria::UI::UIManager do
  it 'works' do
    main_app = instance_double(Alexandria::UI::MainApp)
    described_class.new main_app
  end
end
