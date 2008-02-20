# Copyright (C) 2004-2006 Laurent Sansonetti
# Copyright (C) 2008 Joseph Method
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
  TITLE = 'Alexandria'
  TEXTDOMAIN = 'alexandria'
  extend GetText
  bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")
  DESCRIPTION = _('A program to help you manage your book collection.')
  COPYRIGHT = "Copyright (C) 2004,2005,2006 Laurent Sansonetti\n" +
    "Copyright (C) 2007,2008 Alexandria Contributors"
    AUTHORS = [
             'Alexander McCormmach <alexander@tunicate.org>',
             'Aymeric Nys <aymeric@nnx.com>',
             'Cathal Mc Ginley <cathal.alexandria@gnostai.org>',
             'Claudio Belotti <bel8@lilik.it>',
             'Constantine Evans <cevans@costinet.org>',
             'Dafydd Harries <daf@muse.19inch.net>',
             'Javier Fernandez-Sanguino Pena <jfs@debian.org>',
             'Joseph Method <tristil@gmail.com>',
             'Kevin Schultz <schultkl@ieee.org>',
             'Laurent Sansonetti <lrz@gnome.org>',
             'Marco Costantini <costanti@science.unitn.it>',
             'Mathieu Leduc-Hamel <arrak@arrak.org>',
             'Owain Evans <o.evans@gmail.com>',
             'Pascal Terjan <pterjan@linuxfr.org>',
             'Rene Samselnig <sandman@sdm-net.org>',
             'Robby Stephenson <robby@periapsis.org>',
             'Takayuki Kusano <AE5T-KSN@asahi-net.or.jp>',
             'Timothy Malone <timothy.malone@gmail.com>',
             'Zachary P. Landau <kapheine@hypa.net>'
  ]
  DOCUMENTERS = [
                 'Cathal Mc Ginley <cathal.alexandria@gnostai.org>',
                 'Liam Davison <registrations@liamjdavison.info>'
  ]
  TRANSLATORS = [
                 'Adrián Chaves Fernández <adriyetichaves@gmail.com> (gl)',
                 'CHIKAMA Masaki <masaki.chikama@gmail.com> (ja)',
                 'Cathal Mc Ginley <cathal.alexandria@gnostai.org> (ga)',
                 'Dafydd Harries <daf@muse.19inch.net> (cy)',
                 'David Weinehall <tao@debian.org> (sv)',
                 'Joachim Breitner <mail@joachim-breitner.de> (de)',
                 'José Ling <jlgdot369@gmail.com> (zh_TW)',
                 'L.C. Karssen <lennart@karssen.org> (nl)',
                 'Laurent Sansonetti <lrz@gnome.org> (fr)',
                 'Ligia Moreira <ligia.moreira@netvisao.pt> (pt)',
                 'Lucas Rocha <lucasr@im.ufba.br> (pt_BR)',
                 'Marco Costantini <costanti@science.unitn.it> (it)',
                 'Miguel Ángel García <magmax@ieee.org> (es)',
                 'Mirko Maischberger <mirko@lilik.it> (it)',
                 'Petr Vanek <vanous@penguin.cz> (cs)',
                 'Serhij Dubyk <dubyk@library.lviv.ua> (uk)'
  ]
  ARTISTS = [
             'Andreas Nilsson <nisses.mail@home.se>',
             'Stefanie Dijoux <stefanie.dijoux@gmail.com>'
  ]
  LIST = 'alexandria-list@rubyforge.org'
  BUGREPORT_URL = 'http://rubyforge.org/tracker/?func=add&group_id=205&atid=863'
  WEBSITE_URL = 'http://alexandria.rubyforge.org'
  DONATE_URL = ''
end
