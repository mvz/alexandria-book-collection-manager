# -*- ruby -*-
#--
# Copyright (C) 2011 Cathal Mc Ginley
#
# This file is part of Alexandria, a GNOME book collection manager.
#
# Alexandria is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# Alexandria is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Alexandria; see the file COPYING. If not, write to the
# Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301 USA.
#++

require 'goocanvas'

module Alexandria
  module UI

    class BarcodeAnimation
      
      attr_reader :canvas
      
      def initialize
        @canvas = Goo::Canvas.new
        @canvas.set_size_request(300, 70)
        @canvas.set_bounds(0, 0, 350, 70)
        @root = @canvas.root_item

        @barcode_bars = []
        @barcode_data = [] 

        @hpos = 0

        @scale = 3
        @bar_left_edge = 0
        @bar_top = 8
        @bar_height = 50

        create_ean_barcode_data
        draw_barcode_bars

        @timeout = nil
        @index = 0
        @fade_opacity = 255
        set_active
        @canvas.show
      end

      def start
        @timeout = Gtk.timeout_add(20) do 
          scan_animation
          (@index >= 0)
        end
      end

      def destroy
        @canvas.destroy
        @canvas = nil
      end

      def set_active
        @canvas.set_property(:background_color, "white")
        @barcode_bars.each {|rect| rect.set_property(:fill_color, "white") }
      end
      
      def set_passive
        if @canvas
          passive_bg = "#F4F4F4"
          @canvas.set_property(:background_color, passive_bg)
          @barcode_bars.each {|rect| rect.set_property(:fill_color, passive_bg) }
        end
      end


      def manual_input
        # TODO distinguish between scanner and manual input
        # @canvas.set_property(:background_color, "#FFF8C0")
      end

      def scanner_input
        # TODO distinguish between scanner and manual input
        # @canvas.set_property(:background_color, "white")
      end
      
      private

      def create_ean_barcode_data
        d = '211113123121112331122131113211111123122211132321112311231111'
        #####911113... but that's too much padding on the left...      
        while d.size > 0
          space_width = d[0].chr.to_i
          bar_width = d[1].chr.to_i
          d = d[2..-1]          
          @barcode_data << [space_width, bar_width]          
        end
      end


      def draw_barcode_bars
        @barcode_data.each do |space_width, bar_width|
          @hpos += space_width
          rect_item = Goo::CanvasRect.new(@root, 
                                          @bar_left_edge + @scale*@hpos, @bar_top, 
                                          @scale*bar_width, @bar_height,
                                          :line_width => 0,
                                          :fill_color => 'white')
          @hpos += bar_width
          @barcode_bars << rect_item 
        end
      end

      def scan_animation  
        if @index < @barcode_bars.size
          if @index < 0
            @index = 0
          end
          rect = @barcode_bars[@index]
          alpha = 7 * (@index+1)
          @barcode_bars.each_with_index do |rect, i|
            rect.set_property(:fill_color_rgba, 0xFF000000 + alpha)
            if i >= @index
              break
            end
          end
          @index += 1
        else
          @index = -1
          Gtk.timeout_add(5) do
            @barcode_bars.each {|rect| rect.set_property(:fill_color_rgba, 0x000000C0) }
            Gtk.timeout_add(15) do
              fade_animation
              (@fade_opacity != -1)
            end
            false
          end

        end
      end

      def fade_animation
        if @fade_opacity == -1
          @fade_opacity = 255
        end
        if @fade_opacity >= 0
          grey = 0x00000000 + @fade_opacity
          @barcode_bars.each {|rect| rect.set_property(:fill_color_rgba, grey) }
          @fade_opacity -= 5
        else
          @fade_opacity = -1
        end
      end

    end

  end
end
