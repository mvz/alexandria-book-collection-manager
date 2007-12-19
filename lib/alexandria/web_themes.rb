# Copyright (C) 2004-2006 Laurent Sansonetti
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

module Alexandria
  class WebTheme
    attr_reader :name, :css_file, :preview_file, :pixmaps_directory

    def self.all
      themes_dir = [
                    # System dir
                    File.join(Alexandria::Config::DATA_DIR, "web-themes"),

                    # User dir
                    File.join(ENV['HOME'], '.alexandria', '.web-themes')
                   ]
      themes_dir.map { |x| self.load(x) }.flatten
    end

    def has_pixmaps?
      File.exists?(@pixmaps_directory)
    end

    #######
    private
    #######

    def self.load(themes_dir)
      themes = []
      if File.exists?(themes_dir)
        Dir.entries(themes_dir).each do |file|
          # ignore hidden files
          next if file =~ /^\./
          # ignore non-directories
          path = File.join(themes_dir, file)
          next unless File.directory?(path)
          # ignore CVS directories
          next if file == 'CVS'

          css_file = File.join(path, file + ".css")
          preview_file = File.join(path, "preview.jpg")
          [css_file, preview_file].each do |file|
            raise "#{file} not found" unless File.exists?(file)
          end
          themes << WebTheme.new(css_file, preview_file,
                                 File.join(path, file, "pixmaps"))
        end
      else
        FileUtils.mkdir_p(themes_dir)
      end
      return themes
    end

    def initialize(css_file, preview_file, pixmaps_directory)
      @name = File.basename(css_file, ".css").capitalize
      @css_file = css_file
      @preview_file = preview_file
      @pixmaps_directory = pixmaps_directory
    end
  end
end
