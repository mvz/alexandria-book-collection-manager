# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

# Please retain the following note:
#
# Based upon Recipe 168 - "How to display tooltips in GtkTreeView - Part 3"
# from the "php-gtk2 Cookbook" website, by kksou.
# http://www.kksou.com/php-gtk2/articles/display-tooltips-in-GtkTreeView---Part-3---no-hardcoding-of-header-height.php
#
# Ported to ruby-gtk2 (and modified for IconView) by Cathal Mc Ginley

require "cgi"

module Alexandria
  module UI
    class IconViewTooltips
      include Logging

      def initialize(view)
        set_view(view)
      end

      def set_view(view)
        view.has_tooltip = true
        view.signal_connect("query-tooltip") do |_widget, x, y, _keyboard_mode, tooltip|
          tree_path = view.get_path_at_pos(x, y)
          if tree_path
            iter = view.model.get_iter(tree_path)

            title = iter[2] # HACK: hardcoded, should use column names...
            authors = iter[4]
            publisher = iter[6]
            year = iter[7]
            tooltip.set_markup label_for_book(title, authors, publisher, year)
          end
        end
      end

      def label_for_book(title, authors, publisher, year)
        # This is much too complex... but it works for now!
        html = ""
        unless title.empty?
          html += "<b>#{CGI.escapeHTML(title)}</b>"
          html += "\n" unless authors.empty?
        end
        html += "<i>#{CGI.escapeHTML(authors)}</i>" unless authors.empty?
        html += "\n" if !title.empty? || !authors.empty?

        html += "<small>"
        html += CGI.escapeHTML(publisher).to_s if publisher && !publisher.empty?

        if year && !year.empty?
          html += " " if publisher && !publisher.empty?
          html += "(#{year})"
        end

        html + "</small>"
      end
    end
  end
end
