# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

module Alexandria
  module UI
    class AboutDialog
      GPL = <<~EOL # rubocop:disable GetText/DecorateString
        Alexandria is free software; you can redistribute it and/or
        modify it under the terms of the GNU General Public License as
        published by the Free Software Foundation; either version 2 of the
        License, or (at your option) any later version.

        Alexandria is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY; without even the implied warranty of
        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
        General Public License for more details.

        You should have received a copy of the GNU General Public
        License along with Alexandria; see the file COPYING.  If not,
        write to the Free Software Foundation, Inc., 51 Franklin Street,
        Fifth Floor, Boston, MA 02110-1301 USA.
      EOL

      def initialize(parent)
        @dialog = Gtk::AboutDialog.new
        @dialog.name = Alexandria::TITLE
        @dialog.version = Alexandria::DISPLAY_VERSION
        @dialog.copyright = Alexandria::COPYRIGHT
        @dialog.comments = Alexandria::DESCRIPTION
        @dialog.authors = Alexandria::AUTHORS
        @dialog.documenters = Alexandria::DOCUMENTERS
        @dialog.artists = Alexandria::ARTISTS
        @dialog.translator_credits = Alexandria::TRANSLATORS.join("\n")
        @dialog.logo = Icons::ALEXANDRIA
        @dialog.website = Alexandria::WEBSITE_URL
        @dialog.license = GPL
        @dialog.transient_for = parent
        @dialog.signal_connect("response") { @dialog.destroy }
      end

      def show
        @dialog.show
      end
    end
  end
end
