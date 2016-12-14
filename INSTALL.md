# Installing Alexandria

Alexandria is written in Ruby with a GTK+3/GNOME user-interface. It
currently only runs on UNIX-style systems, such as GNU/Linux.

Alexandria is not an easy project to build from scratch. Apart from
Ruby and GNOME, it has a lot of dependencies. Once the dependencies have been
installed, however, building and installing Alexandria is relatively
straightforward.

## Dependencies

The [Ruby-GNOME2](http://ruby-gnome2.sourceforge.jp/) user-interface
involves a number of packages:

* `gtk3`
* `gio2`
* `gstreamer`

You should have GTK+ 3, and use Ruby-GNOME2 `~> 3.1.0`.

[`ruby-gettext`](http://ruby-gettext.github.io/)
is required for the internationalisation of the user interface.
Requires version `~> 3.1`.

### Hpricot

Alexandria uses [hpricot](https://github.com/hpricot/hpricot) to
parse the HTML from web pages for providers such as DeaStore and
Siciliano. It is also used to parse the XML for the Amazon web
service.

## HTMLEntities

This is used by all website-based providers except MCU.
[htmlentities](https://github.com/threedaymonk/htmlentities) is used to
provide more flexible HTML parsing.

## Build Dependencies

### Ruby Dependencies

[`rake`](https://github.com/ruby/rake) is required to build Alexandria from
the project `Rakefile`.

You also need [`rubygems`](http://www.rubygems.org/) and
[`rspec`](http://rspec.rubyforge.org/) to run the RSpec test suite.

### Native Dependencies

The [`gettext`](http://www.gnu.org/software/gettext) package is needed
to generate the binary `mo` files used by `ruby-gettext` at
runtime. You also need the
[`intltool`](http://www.freedesktop.org/wiki/Software/intltool) package
to merge translations into generated files (and to extract
translatable string from xml files during development).

Note that these files are pre-generated in tar.gz releases, so you'll
only need them if you're building from the SVN version, or want to
change the translations.

### Ruby/ZOOM and Yaz

For Z39.50 support and and the *Library of Congress* and
*British Library* book providers you will need
[`ruby-zoom`](http://ruby-zoom.rubyforge.org), which in turn
requires the non-Ruby package [`yaz`](http://www.indexdata.dk/yaz).

Note that if you install the recent Ruby/ZOOM as the `zoom` gem, you
will also need to install the `marc` gem. (Older implementations of
ruby-zoom contained their own implementation of MARC.)

The Z39.50 Object-Orientation Model (ZOOM) is an international
standard for communication between computer systems, particularly
libraries and information-related systems.

### image_size

You will need
[`image_size`](https://github.com/toy/image_size) for
optimizing the cover images in exported libraries.

## Installing Alexandria

After installing all the non-Ruby dependencies, you should be able to install alexandria using

    gem install alexandria-book-collection-manager

## Installing from Source

**These instructions are outdated and you should for now install alexandria as a gem**

To build Alexandria from a git checkout, go to the base project
directory (where the Rakefile and this INSTALL file are located) and
issue the command

    rake build

If you have downloaded a source package, this step will not usually be
necessary.

You must have root priveledges to install, so use `su`
    su -c 'rake install'
or `sudo`
    sudo rake install

Now you can check the version of the installed Alexandria
    alexandria --version

To launch Alexandria, simply use
    alexandria

If you wish to see more output on the console, you can use
    alexandria --debug

### Staged installation for making packages

When building a binary package (such as a deb or rpm) you will want to
"install" Alexandria into a specified directory instead of the root
filesystem. You should specify this as the DESTDIR environment variable
and use the `install_package_staging` task instead of `install`

    DESTDIR=debian/alexandria rake install_package_staging

If your distribution uses a specific directory to install Ruby
packages, you should also set the RUBYLIBDIR.

### Installing in the home directory

If you want to install Alexandria in your home directory, you should
specify the PREFIX, SHARE and RUBYLIBDIR envrionment variables, and
use the `install_package` task instead of `install`.

    PREFIX=$HOME SHARE=$HOME/.share RUBYLIBDIR=$HOME/.rubylib rake install_package

This will install the `alexandria` program into `$HOME/bin` (which you
should add to your `PATH`), and the ruby files to your
`$HOME/.rubylib` which you should add to your `RUBYLIBDIR` environment
variable.

### Uninstalling

To uninstall, simply run

    sudo rake uninstall

(or `rake uninstall_package` if you installed in your home directory).

If you specified any of the environment variables PREFIX, SHARE,
RUBYLIBDIR and DESTDIR during the installation, you should use the
same variables during uninstallation (or rake won't know where to look
for the files it has to remove).
