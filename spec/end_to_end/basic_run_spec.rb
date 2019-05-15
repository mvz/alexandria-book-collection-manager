# frozen_string_literal: true

# Copyright (C) 2018 Matijs van Zuijlen
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

require 'gnome_app_driver'
require 'tmpdir'

describe 'The Alexandria application' do
  before do
    ENV['HOME'] = Dir.mktmpdir
    @driver = GnomeAppDriver.new 'alexandria'
    @driver.boot
  end

  after do
    @driver.cleanup
  end
  it 'starts and can be quit with Ctrl-q' do
    @driver.press_ctrl_q

    status = @driver.cleanup
    expect(status.exitstatus).to eq 0
  end

  it 'starts and can be quit with the menu' do
    frame = @driver.frame
    menu = frame.find_role :menu_item, /Quit/
    menu.do_action 0

    status = @driver.cleanup
    expect(status.exitstatus).to eq 0
  end

  it 'can be interacted with' do
    frame = @driver.frame
    frame.find_role(:menu_item, /Title contains/).do_action 0
    frame.find_role(:menu_item, /View as Icons/).do_action 0
    frame.find_role(:menu_item, /View as List/).do_action 0
    frame.find_role(:table_column_header, /Title/).do_action 0

    table_cell = frame.find_role(:table_cell)

    table_cell.n_actions.times do |idx|
      name = table_cell.get_action_name idx
      table_cell.do_action idx if name == 'activate'
    end

    @driver.press_ctrl_q

    status = @driver.cleanup
    expect(status.exitstatus).to eq 0
  end
end
