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

module Alexandria 
    TITLE = 'Alexandria'
    TEXTDOMAIN = 'alexandria'
    extend GetText
    bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")
    DESCRIPTION = _('A program to help you manage your book collection.')
    COPYRIGHT = 'Copyright (C) 2004 Laurent Sansonetti'
    AUTHORS = [
        'Dafydd Harries <daf@muse.19inch.net>',
        'Laurent Sansonetti <lrz@gnome.org>',
        'Pascal Terjan <pterjan@linuxfr.org>',
        'Robby Stephenson <robby@periapsis.org>',
        'Takayuki Kusano <AE5T-KSN@asahi-net.or.jp>',
        'Zachary P. Landau <kapheine@hypa.net>'
    ]
    DOCUMENTERS = []  
    TRANSLATORS = [ 
        'Dafydd Harries <daf@muse.19inch.net> (cy)',
        'Joachim Breitner <mail@joachim-breitner.de> (de)',
        'Laurent Sansonetti <lrz@gnome.org> (fr)',
        'Masao Mutoh <mutoh@highway.ne.jp> (ja)',
        'Miguel Angel Garcia <miguela.garcia3@alu.uclm.es> (es)'
    ]
    LIST = 'alexandria-list@rubyforge.org'
    BUGREPORT_URL = 'http://rubyforge.org/tracker/?func=add&group_id=205&atid=863'
    WEBSITE_URL = 'http://alexandria.rubyforge.org'

    def self.main
        $DEBUG = !ENV['DEBUG'].nil?
        ENV['http_proxy'] = nil if !ENV['http_proxy'].nil? \
                                and URI.parse(ENV['http_proxy']).userinfo.nil?
        Alexandria::UI.main
    end
end

require 'alexandria/config'
require 'alexandria/version'
require 'alexandria/book'
require 'alexandria/library'
require 'alexandria/import_library'
require 'alexandria/export_library'
require 'alexandria/book_providers'
require 'alexandria/preferences'
require 'alexandria/web_themes'
require 'alexandria/ui'
