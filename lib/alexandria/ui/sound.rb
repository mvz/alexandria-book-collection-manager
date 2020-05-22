# frozen_string_literal: true

# -*- ruby -*-
#--
# Copyright (C) 2011 Cathal Mc Ginley
# Copyright (C) 2015, 2016 Matijs van Zuijlen
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

require "gir_ffi-gst"
Gst.init

module Alexandria
  module UI
    ## Uses Ruby/GStreamer to play Ogg/Vorbis sound effects
    class SoundEffectsPlayer
      def initialize
        @sounds_dir = Alexandria::Config::SOUNDS_DIR
        @ogg_vorbis_pipeline = Gst::Pipeline.new "pipeline"
        set_up_pipeline
        @playing = false
        set_up_bus_watch
      end

      def play(effect)
        file = File.join(@sounds_dir, "#{effect}.ogg")
        if @playing
          log.debug { "Already playing #{effect}." }
        else
          log.debug { "Not playing. Starting #{effect}." }
          @filesrc.location = file
          start_playback
        end
      end

      def set_up_pipeline
        @filesrc = Gst::ElementFactory.make("filesrc", "file source")
        demuxer = Gst::ElementFactory.make("oggdemux", "demuxer")
        decoder = Gst::ElementFactory.make("vorbisdec", "decoder")
        converter = Gst::ElementFactory.make("audioconvert", "converter") # #??
        audiosink = Gst::ElementFactory.make("autoaudiosink", "audiosink")

        @ogg_vorbis_pipeline.add_many([@filesrc, demuxer, decoder,
                                       converter, audiosink])
        @filesrc.link demuxer

        # this next must be a dynamic link, as demuxers potentially
        # have multiple src pads (for audio/video muxed streams)

        demuxer.signal_connect("pad-added") do |_parser, ogg_src_pad|
          vorbis_sink_pad = decoder.sinkpads.first
          ogg_src_pad.link(vorbis_sink_pad)
        end

        decoder.link_many([converter, audiosink])
      end

      def set_up_bus_watch
        @bus = @ogg_vorbis_pipeline.bus
        @bus.add_watch GLib::PRIORITY_DEFAULT do |_bus, message|
          case message.type
          when Gst::MessageType::EOS
            stop_playback
          when Gst::MessageType::ERROR
            log.debug { "ERROR loop.quit" }
            log.debug { message.parse.inspect }
            stop_playback
          end
          true
        end
      end

      def start_playback
        @playing = true
        @ogg_vorbis_pipeline.play
      end

      def stop_playback
        @ogg_vorbis_pipeline.stop
        @playing = false
      end
    end
  end
end
