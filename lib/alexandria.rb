# Copyright (C) 2004 Laurent Sansonetti
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
# write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

require 'alexandria/config.rb'
require 'alexandria/book.rb'
require 'alexandria/preferences.rb'
require 'alexandria/ui.rb'

module Alexandria
    TITLE = 'Alexandria'
    VERSION = '0.1.2'
    DESCRIPTION = 'A program to help you manage your book collection.'
    COPYRIGHT = 'Copyright (C) 2004 Laurent Sansonetti'
    AUTHORS = [
        'Dafydd Harries <daf@muse.19inch.net>',
        'Laurent Sansonetti <lrz@gnome.org>',
        'Zachary P. Landau <kapheine@hypa.net>'
    ]
    DOCUMENTERS = [ 'Laurent Sansonetti <lrz@gnome.org>' ]  
    TRANSLATORS = [ 'Laurent Sansonetti <lrz@gnome.org>' ]
    LIST = 'alexandria-list@rubyforge.org'
    BUGREPORT_URL = 'http://rubyforge.org/tracker/?func=add&group_id=205&atid=863'

    def self.main
        $DEBUG = !ENV['DEBUG'].nil?
        Alexandria::UI.main
    end
end
