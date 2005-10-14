# Copyright (C) 2004-2005 Laurent Sansonetti
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
    COPYRIGHT = 'Copyright (C) 2004-2005 Laurent Sansonetti'
    AUTHORS = [
        'Alexander McCormmach <alexander@tunicate.org>',
        'Claudio Belotti <bel8@lilik.it>',
        'Constantine Evans <cevans@costinet.org>',
        'Dafydd Harries <daf@muse.19inch.net>',
        'Javier Fernandez-Sanguino Pena <jfs@debian.org>',
        'Kevin Schultz <schultkl@ieee.org>',
        'Laurent Sansonetti <lrz@gnome.org>',
        'Owain Evans <o.evans@gmail.com>',
        'Pascal Terjan <pterjan@linuxfr.org>',
        'Rene Samselnig <sandman@sdm-net.org>',
        'Robby Stephenson <robby@periapsis.org>',
        'Takayuki Kusano <AE5T-KSN@asahi-net.or.jp>',
        'Zachary P. Landau <kapheine@hypa.net>'
    ]
    DOCUMENTERS = [
        'Liam Davison <registrations@liamjdavison.info>'
    ]
    TRANSLATORS = [ 
        'Dafydd Harries <daf@muse.19inch.net> (cy)',
        'David Weinehall <tao@debian.org> (sv)',
        'Jiri Pejchal <jiri.pejchal@gmail.com> (cs)',
        'Joachim Breitner <mail@joachim-breitner.de> (de)',
        'Laurent Sansonetti <lrz@gnome.org> (fr)',
        'Ligia Moreira <ligia.moreira@netvisao.pt> (pt)',
        'Lucas Rocha <lucasr@im.ufba.br> (pt_BR)',
        'Masao Mutoh <mutoh@highway.ne.jp> (ja)',
        'Miguel Angel Garcia <miguela.garcia3@alu.uclm.es> (es)',
        'Mirko Maischberger <mirko@lilik.it> (it)'
    ]
    ARTISTS = [
        'Stefanie Dijoux <stefanie.dijoux@gmail.com>'
    ]
    LIST = 'alexandria-list@rubyforge.org'
    BUGREPORT_URL = 'http://rubyforge.org/tracker/?func=add&group_id=205&atid=863'
    WEBSITE_URL = 'http://alexandria.rubyforge.org'
    DONATE_URL = 'https://www.paypal.com/cgi-bin/webscr?cmd=_xclick&business=lrz%40rubymonks%2eorg&item_name=Alexandria&no_shipping=0&no_note=1&currency_code=EUR'

    def self.main
        $DEBUG = !ENV['DEBUG'].nil?
        ENV['http_proxy'] = nil if !ENV['http_proxy'].nil? \
                                and URI.parse(ENV['http_proxy']).userinfo.nil?
        Alexandria::UI.main
    end
end

unless $MACOSX
    require 'alexandria/config'
    require 'alexandria/version'
else
    module Alexandria
        module Config
            DATA_DIR = OSX::NSBundle.mainBundle.resourcePath.fileSystemRepresentation
        end
        VERSION = OSX::NSBundle.mainBundle.infoDictionary.objectForKey('CFBundleVersion').to_s
    end
end

require 'alexandria/book'
require 'alexandria/utils'
require 'alexandria/library'
require 'alexandria/execution_queue'
require 'alexandria/import_library'
require 'alexandria/export_library'
require 'alexandria/book_providers'
require 'alexandria/preferences'
require 'alexandria/web_themes'

require $MACOSX ? 'alexandria/macui' : 'alexandria/ui'
