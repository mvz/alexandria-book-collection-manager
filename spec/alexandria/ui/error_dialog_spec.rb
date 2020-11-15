# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::UI::ErrorDialog do
  let(:parent) { Gtk::Window.new :toplevel }

  it "works" do
    expect { described_class.new parent, "Boom", "It went boom" }.not_to raise_error
  end

  describe "display" do
    let(:instance) { described_class.new parent, "Boom", "It went boom" }
    let(:dialog) { instance.dialog }

    it "works when response is OK" do
      allow(dialog).to receive(:run).and_return(Gtk::ResponseType::OK)
      expect { instance.display }.not_to raise_error
    end
  end
end
