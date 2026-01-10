# Changelog

## 0.7.11 / 2026-01-10

* Support Ruby 3.2 through 4.0
  ([#216], [#235], [#213], [#252], [#255], [#264], [#278] and [#284] by [mvz])
* Update Italian translation ([#272] by [albanobattistella])
* Remove broken or obsolete online book viewing URLs ([#207] by [mvz])
* Improve KeyboardWedge scanner ([#231] by [mvz])
* Prevent Nokogiri's custom libxml memory management breaking Gtk+ widget
  ([#247] by [mvz])
* Replace zoom with alexandria-zoom ([#224] by [mvz])
* Update gstreamer and gtk3 dependencies ([#219], [#244] and [#275] by [mvz])
* Loosen, simplify and update marc version requirement ([#266] by [mvz])

[albanobattistella]: https://github.com/albanobattistella

[#207]: https://github.com/mvz/alexandria-book-collection-manager/pull/207
[#213]: https://github.com/mvz/alexandria-book-collection-manager/pull/213
[#216]: https://github.com/mvz/alexandria-book-collection-manager/pull/216
[#219]: https://github.com/mvz/alexandria-book-collection-manager/pull/219
[#224]: https://github.com/mvz/alexandria-book-collection-manager/pull/224
[#231]: https://github.com/mvz/alexandria-book-collection-manager/pull/231
[#235]: https://github.com/mvz/alexandria-book-collection-manager/pull/235
[#244]: https://github.com/mvz/alexandria-book-collection-manager/pull/244
[#247]: https://github.com/mvz/alexandria-book-collection-manager/pull/247
[#252]: https://github.com/mvz/alexandria-book-collection-manager/pull/252
[#255]: https://github.com/mvz/alexandria-book-collection-manager/pull/255
[#264]: https://github.com/mvz/alexandria-book-collection-manager/pull/264
[#266]: https://github.com/mvz/alexandria-book-collection-manager/pull/266
[#270]: https://github.com/mvz/alexandria-book-collection-manager/pull/270
[#271]: https://github.com/mvz/alexandria-book-collection-manager/pull/271
[#272]: https://github.com/mvz/alexandria-book-collection-manager/pull/272
[#275]: https://github.com/mvz/alexandria-book-collection-manager/pull/275
[#278]: https://github.com/mvz/alexandria-book-collection-manager/pull/278
[#284]: https://github.com/mvz/alexandria-book-collection-manager/pull/284

## 0.7.10 / 2022-10-14

* Loosen dependency on the marc gem
* Update dependency on the gtk3 and gstreamer gems
* Make Alexandria's own MARC parser handle nil records ([#198] by [mvz])
* Support upcoming Ruby 3.2

[#198]: https://github.com/mvz/alexandria-book-collection-manager/pull/198

## 0.7.9 / 2022-02-04

* Drop support for Ruby 2.5
* Support up to Ruby 3.1
* Fix crash when renaming a Library ([#112] by [mvz])
* Remove broken book data providers: Siciliano, AdLibris, Proxis and Barnes and
  Noble ([#115] by [mvz])
* Remove Amazon provider ([#118] by [mvz])
* Remove references to obsolete MCE (Spanish Ministry of Culture) provider from
  documentation ([#119] by [mvz])
* Use nokogiri instead of hpricot, which is no longer being maintained ([#120]
  by [mvz])
* Filter out Library objects when loading Book from yaml ([#133] by [mvz])
* Fix selection update when added book does not match current filter ([#134] by
  [mvz])
* Recognize negative integers in GConf settings (#136] by [mvz])
* Fix source for shared items to install ([#139] by [mvz])
* Various dependency updates

[mvz]: https://github.com/mvz

[#139]: https://github.com/mvz/alexandria-book-collection-manager/pull/139
[#136]: https://github.com/mvz/alexandria-book-collection-manager/pull/136
[#134]: https://github.com/mvz/alexandria-book-collection-manager/pull/134
[#133]: https://github.com/mvz/alexandria-book-collection-manager/pull/133
[#120]: https://github.com/mvz/alexandria-book-collection-manager/pull/120
[#119]: https://github.com/mvz/alexandria-book-collection-manager/pull/119
[#118]: https://github.com/mvz/alexandria-book-collection-manager/pull/118
[#115]: https://github.com/mvz/alexandria-book-collection-manager/pull/115
[#112]: https://github.com/mvz/alexandria-book-collection-manager/pull/112

## 0.7.8 / 2020-11-29

* Fix ThaliaProvider
* Avoid warnings for calendar popup
* Make Rename menu item work
* Fix crash when changing covers
* Make alerts show alert details if available

## 0.7.7 / 2020-11-15

* Update Polish translation ([#88] by [Piotr Drąg][piotrdrag])
* Fix hiding of progress bar of import dialog
* Fix calendar popups in Smart Library and Book Properties dialogs
* Fix crashes when activating Export and Import menu items

[#88]: https://github.com/mvz/alexandria-book-collection-manager/pull/88

## 0.7.6 / 2020-11-01

* Make more strings translatable with help from rubocop-i18n
* Code quality and testing infrastructure improvements
* Update Polish translation ([#51] and [#64], by [Piotr Drąg][piotrdrag])
* Update Dutch translation
* Make several dialogs that stopped appearing appear again
* Remove ability to enable and disable providers through a pop-up menu
* Fix New Library functionality
* Update dependencies on gtk3, gstreamer, and psych
* Fix issues in preferences, smart library dialog, and book selection
* Improve installation instructions
* Improve README ([#83] by [Happy][HappyFacade])

[piotrdrag]: https://github.com/piotrdrag
[HappyFacade]: https://github.com/HappyFacade

[#83]: https://github.com/mvz/alexandria-book-collection-manager/pull/83
[#64]: https://github.com/mvz/alexandria-book-collection-manager/pull/64
[#51]: https://github.com/mvz/alexandria-book-collection-manager/pull/51

## 0.7.5 / 2020-05-11

* Avoid crash when opening Import dialog
* Avoid crash during export
* Add support for Ruby 2.7
* Drop support for Ruby 2.4
* Remove broken Renaud provider

## 0.7.4 / 2019-10-24

* Drop support for Ruby 2.3
* Avoid passing nil to Gtk method #visible=, which expects a boolean
  ([#23], by [Joseph Haig][jrmhaig])
* Update dependencies on gtk3 and gstreamer to 3.4.1
* Fix WorldCat provider to use https

[jrmhaig]: https://github.com/jrmhaig
[#23]: https://github.com/mvz/alexandria-book-collection-manager/pull/23

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

[#19]: https://github.com/mvz/alexandria-book-collection-manager/issues/19

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
