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

require 'gettext'
require 'logger'
require 'alexandria/logging'
require 'alexandria/about'

module Alexandria

  def self.set_proxy
    ENV['http_proxy'] = nil if !ENV['http_proxy'].nil? \
      and URI.parse(ENV['http_proxy']).userinfo.nil?
  end

  def self.set_log_level
    if $DEBUG
      Alexandria.log.level = Logger::DEBUG
    end
    Alexandria.log.debug { "Initializing Alexandria..." }
  end

  def self.main
    set_proxy
    set_log_level
    Alexandria::UI.main
  end
end


# lrz says 'macui' is obsolete (may be supported again some day)
#unless $MACOSX
require 'alexandria/config'
require 'alexandria/version'

#else
#  module Alexandria
#    module Config
#      DATA_DIR = OSX::NSBundle.mainBundle.resourcePath.fileSystemRepresentation
#    end
#    VERSION = OSX::NSBundle.mainBundle.infoDictionary.objectForKey('CFBundleVersion').to_s
#  end
#end
require 'alexandria/utils'

require 'alexandria/models/book'
require 'alexandria/models/library'

require 'alexandria/smart_library'
require 'alexandria/execution_queue'
require 'alexandria/import_library'
require 'alexandria/export_library'
require 'alexandria/book_providers'
require 'alexandria/preferences'
require 'alexandria/undo_manager'
require 'alexandria/web_themes'

# lrz says 'macui' is obsolete (may be supported again some day)
# require $MACOSX ? 'alexandria/macui' : 'alexandria/ui'

require 'alexandria/ui'
require 'alexandria/console'
