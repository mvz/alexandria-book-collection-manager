# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "gnome_app_driver"
require "tmpdir"

describe "The Alexandria application" do
  # TODO: Remove app_file argument once GnomeAppDriver is smart about executable location
  let(:driver) { GnomeAppDriver.new "alexandria", app_file: "exe/alexandria" }

  before do
    ENV["HOME"] = Dir.mktmpdir
    driver.boot
  end

  after do
    driver.cleanup
  end

  it "starts and can be quit with the menu" do
    frame = driver.frame
    menu = frame.find_role :menu_item, /Quit/
    menu.do_action 0

    status = driver.cleanup
    expect(status.exitstatus).to eq 0
  end

  it "can be interacted with" do
    frame = driver.frame
    frame.find_role(:menu_item, /Title contains/).do_action 0
    frame.find_role(:menu_item, /View as Icons/).do_action 0
    frame.find_role(:menu_item, /View as List/).do_action 0
    frame.find_role(:table_column_header, /Title/).do_action 0

    table_cell = frame.find_role(:table_cell)

    table_cell.n_actions.times do |idx|
      name = table_cell.get_action_name idx
      table_cell.do_action idx if name == "activate"
    end

    frame = driver.frame
    menu = frame.find_role :menu_item, /Quit/
    menu.do_action 0

    status = driver.cleanup
    expect(status.exitstatus).to eq 0
  end
end
