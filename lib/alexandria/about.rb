module Alexandria
  TITLE = 'Alexandria'
  TEXTDOMAIN = 'alexandria'
  extend GetText
  bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")
  DESCRIPTION = _('A program to help you manage your book collection.')
  COPYRIGHT = "Copyright (C) 2004-2006 Laurent Sansonetti\n" +
    "Copyright (C) 2007 Alexandria Contributors"
    AUTHORS = [
             'Alexander McCormmach <alexander@tunicate.org>',
             'Aymeric Nys <aymeric@nnx.com>',
             'Cathal Mc Ginley <cathal.alexandria@gnostai.org>',
             'Claudio Belotti <bel8@lilik.it>',
             'Constantine Evans <cevans@costinet.org>',
             'Dafydd Harries <daf@muse.19inch.net>',
             'Javier Fernandez-Sanguino Pena <jfs@debian.org>',
             'Kevin Schultz <schultkl@ieee.org>',
             'Laurent Sansonetti <lrz@gnome.org>',
             'Marco Costantini <costanti@science.unitn.it>',
             'Mathieu Leduc-Hamel <arrak@arrak.org>',
             'Owain Evans <o.evans@gmail.com>',
             'Pascal Terjan <pterjan@linuxfr.org>',
             'Rene Samselnig <sandman@sdm-net.org>',
             'Robby Stephenson <robby@periapsis.org>',
             'Takayuki Kusano <AE5T-KSN@asahi-net.or.jp>',
             'Zachary P. Landau <kapheine@hypa.net>',
             'Joseph Method <tristil@gmail.com>'
  ]
  DOCUMENTERS = [
                 'Liam Davison <registrations@liamjdavison.info>',
                 'Cathal Mc Ginley <cathal.alexandria@gnostai.org>',
  ]
  TRANSLATORS = [
                 'CHIKAMA Masaki <masaki.chikama@gmail.com> (ja)',
                 'Dafydd Harries <daf@muse.19inch.net> (cy)',
                 'David Weinehall <tao@debian.org> (sv)',
                 'Jiri Pejchal <jiri.pejchal@gmail.com> (cs)',
                 'Joachim Breitner <mail@joachim-breitner.de> (de)',
                 'L.C. Karssen <lennart@karssen.org>',
                 'Laurent Sansonetti <lrz@gnome.org> (fr)',
                 'Ligia Moreira <ligia.moreira@netvisao.pt> (pt)',
                 'Lucas Rocha <lucasr@im.ufba.br> (pt_BR)',
                 'Marco Costantini <costanti@science.unitn.it> (it)',
                 'Miguel Ángel García <magmax@ieee.org> (es)',
                 'Mirko Maischberger <mirko@lilik.it> (it)',
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
