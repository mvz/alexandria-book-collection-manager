# Alexandria

Alexandria is a GNOME application for managing collections of books.

Alexandria is written in Ruby, and is free software, distributed under
the terms of the GNU General Public License, version 2 or later. See
the file [COPYING](COPYING) for more information.

What is Alexandria?
===================

Alexandria is an application for managing a personal book library.
Its main recommending feature is its clean, intuitive interface.
Alexandria is able to retrieve book information and cover images from
a wide variety of online data sources. It also features extensive
import and export options, a loan interface, and smart libraries.
Alexandria is written in Ruby using ruby-gnome2.

Where can I get it?
===================

You can install alexandria as a gem by running

    gem install alexandria-book-collection-manager

Alternatively, download the source from the github repository at
http://www.github.com/mvz/alexandria-book-collection-manager and follow the
installation instructions.

Where can I find out more?
==========================

For source code and bug reporting, see the repository on github at
http://www.github.com/mvz/alexandria-book-collection-manager.

## Features

Alexandria is a simple program designed to allow individuals to keep a
catalogue of their book collection. In addition, it enables users to
keep track of books which are on loan.

* retrieves and displays book information (sometimes with cover
  pictures) from several online libraries and bookshops, such as
   - Amazon
   - Proxis
   - Spanish Ministry of Culture
   - WorldCat
   - US Library of Congress
   - British Library
* allows books to be added and updated by hand
* enables searches either by ISBN, title, author or keyword
* supports the Z39.50 standard and allow you to manage your own
  sources (e.g. university libraries)
* saves data using the plain-text YAML format
* can import and export data into ONIX, Tellico, ISBN-list
  and GoodReads CSV formats
* can export XHTML web pages of your libraries, themable with CSS
* allows marking your books as loaned, each with the loan-date and
  the name of the person who has borrowed them
* features a HIG-compliant user interface
* shows books in different views (standard list or icons list),
  that can be filtered and/or sorted
* handles book rating and notes
* supports CueCat and standard "keyboard wedge" barcode readers
* includes translations for several languages
* is documented in a complete manual (at the moment only in
  English and Japanese)

Alexandria is not without problems. See [doc/BUGS](doc/BUGS) for a
summary of issues.

## Installation

There are full instructions for installing Alexandria from source in the
file [INSTALL](INSTALL), including information about all the dependencies.

If you are installing on a Debian-based system, things should be
easier as the dependencies can be handled automatically.

To run the program, just type
    `alexandria`
or, to get verbose debugging information,
    `alexandria --debug`

If you are running GNOME, Alexandria should appear under the
'Applications > Office' menu.

## Contributors

The following people have contributed to Alexandria over the years:

### Authors

* Alexander McCormmach <alexander@tunicate.org>
* Aymeric Nys <aymeric@nnx.com>
* Cathal Mc Ginley <cathal.alexandria@gnostai.org>
* Claudio Belotti <bel8@lilik.it>
* Constantine Evans <cevans@costinet.org>
* Dafydd Harries <daf@muse.19inch.net>
* Javier Fernandez-Sanguino Pena <jfs@debian.org>
* Joseph Haig <josephhaig@gmail.com>
* Joseph Method <tristil@gmail.com>
* Kevin Schultz <schultkl@ieee.org>
* Laurent Sansonetti <lrz@gnome.org>
* Marco Costantini <costanti@science.unitn.it>
* Mathieu Leduc-Hamel <arrak@arrak.org>
* Matijs van Zuijlen <matijs@matijs.net>
* Owain Evans <o.evans@gmail.com>
* Pascal Terjan <pterjan@linuxfr.org>
* Rene Samselnig <sandman@sdm-net.org>
* Robby Stephenson <robby@periapsis.org>
* Sun Ning <classicning@gmail.com>
* Takayuki Kusano <AE5T-KSN@asahi-net.or.jp>
* Timothy Malone <timothy.malone@gmail.com>
* Zachary P. Landau <kapheine@hypa.net>

### Documenters

* Cathal Mc Ginley <cathal.alexandria@gnostai.org>
* Liam Davison <registrations@liamjdavison.info>

### Artists

* Andreas Nilsson <nisses.mail@home.se>
* Stefanie Dijoux <stefanie.dijoux@gmail.com>

### Translators

* Adrián Chaves Fernández <adriyetichaves@gmail.com> (gl)
* Cathal Mc Ginley <cathal.alexandria@gnostai.org> (ga)
* CHIKAMA Masaki <masaki.chikama@gmail.com> (ja)
* Dafydd Harries <daf@muse.19inch.net> (cy)
* Damjan Dimitrioski <damjandimitrioski@gmail.com> (mk)
* Giacomo Margarito <giacomomargarito@gmail.com> (it)
* Jack Myrseh <jack@enkom.no> (nb)
* Joachim Breitner <mail@joachim-breitner.de> (de)
* José Ling <jlgdot369@gmail.com> (zh_TW)
* Lennart Karssen <lennart@karssen.org> (nl)
* Lígia Moreira <ligia.moreira@netvisao.pt> (fr, pt, pt_BR)
* Martin Karlsson <martinkarlsson81@hotmail.com> (sv)
* Michael Kotsarinis <mkotsari1@pre.forthnet.gr> (el)
* Miguel Ángel García <magmax@ieee.org> (es)
* Peter Kováč <kovac.peter@fotopriestor.sk> (sk)
* Petr Vanek <vanous@penguin.cz> (cs)
* Piotr Drąg <piotrdrag@gmail.com> (pl)
* Serhij Dubyk <dubyk@library.lviv.ua> (uk)

### Former translators
* David Weinehall <tao@debian.org> (sv)
* Jiří Pejchal <jiri.pejchal@gmail.com> (cs)
* Laurent Sansonetti <lrz@gnome.org> (fr)
* Lucas Rocha <lucasr@im.ufba.br> (pt_BR)
* Marco Costantini <costanti@science.unitn.it> (it)
* Masao Mutoh <mutoh@highway.ne.jp> (ja)
* Mirko Maischberger <mirko@lilik.it> (it)

## License

Unless otherwise noted, the following license applies to all files that are
part of Alexandria:

Copyright (C) 2004 Laurent Sansonetti
Copyright (C) 2005-2010,2014-2020 Alexandria Contributors

Alexandria is free software; you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version. See the file [COPYING](COPYING) for details.
