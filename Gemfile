# frozen_string_literal: true

source "https://rubygems.org"

# The gem's dependencies are specified in the gemspec
gemspec

group :development, :test do
  gem "pry"
  gem "simplecov"
  gem "yard", "~> 0.9.5"
end

git "https://github.com/mvz/ruby-gnome", branch: "type-error-patch-2" do
  gem "atk"
  gem "cairo-gobject"
  gem "gdk3"
  gem "gdk_pixbuf2"
  gem "gio2"
  gem "glib2"
  gem "gobject-introspection"
  gem "gstreamer"
  gem "gtk3"
  gem "pango"
end
