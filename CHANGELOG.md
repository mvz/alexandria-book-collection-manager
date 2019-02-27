# Changelog

## 0.7.3 / 2019-02-27

* Remove DeaStore provider since the site is no longer online
* Remove MCU provider since the site is no longer online
* Various code cleanups
* Update dependencies on `gstreamer`, `gtk3` and `image_size`
* Call `#set_active` with `false` instead of `nil` (Fixes [#19])
* Spec and fix export functionality
* Do not hard-code storage location
* Silence some Gtk+ warnings
* Fix setup of default scanner when no scanner is configured
* Update `YAML.safe_load` calls to new API, silencing deprecation warnings

## 0.7.2 / 2018-03-18

* Update dependencies
* Various code cleanups

## 0.7.1 / 2016-12-13

* Various code cleanups
* Update dependencies
* Don't crash if smart library name uses non-UTF-8 encoding

## 0.7.0

* Various small bug fixes
* Update to ruby-gnome2 3.0.9
* Improve specs
* Port to Gtk+ 3
* Restore Barcode animation
* Remove old String#convert monkey-patch
* Simplify sound system and stop it from hanging Alexandria

## 0.6.9

* Update/fix authorship information and other metadata
* Fix crash opening preferences dialog
* Fix crash opening book dialog
* Clean up code
* Merge tests into specs
* Update dependencies to latest gtk2 and gstreamer gems

## 0.6.9.pre1

* Start providing a gemspec to allow installation as a gem
* Disable some broken web scrapers
* Update specs and tests
* Modernize build environment

## 0.6.8

* Removed dependencies on deprecated Ruby/GNOME2 libraries, to get
  Alexandria working on Ubuntu 11.10.
* Added dependencies on ruby-gst and ruby-goocanvas
* Added Barcode Scanner tab to Preferences dialog

## 0.6.7

* Added auto-completion for tags in Book Properties
* Amazon queries now use a Associate Tag, a new requirement of
  Amazon's Product Advertising API. Thanks to Stephen McCamant for
  providing the patch.

<!-- references -->

[#19]: https://github.com/mvz/alexandria-book-collection-manager/issues/19
