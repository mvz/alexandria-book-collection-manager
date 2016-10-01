# -*- ruby -*-
#
# Copyright (C) 2007 kksou
# Copyright (C) 2008,2009 Cathal Mc Ginley
# Copyright (C) 2011, 2014, 2016 Matijs van Zuijlen
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

# Please retain the following note:
#
# Based upon Recipe 168 - "How to display tooltips in GtkTreeView - Part 3"
# from the "php-gtk2 Cookbook" website, by kksou.
# http://www.kksou.com/php-gtk2/articles/display-tooltips-in-GtkTreeView---Part-3---no-hardcoding-of-header-height.php
#
# Ported to ruby-gtk2 (and modified for IconView) by Cathal Mc Ginley

require 'cgi'

class IconViewTooltips
  include Alexandria::Logging

  def initialize(view)
    set_view(view)
  end

  def set_view(view)
    view.has_tooltip = true
    view.signal_connect('query-tooltip') do |widget, x, y, keyboard_mode, tooltip|
      tree_path = view.get_path_at_pos(x, y)
      if tree_path
        iter = view.model.get_iter(tree_path)

        title = iter[2] # HACK hardcoded, should use column names...
        authors = iter[4]
        publisher = iter[6]
        year = iter[7]
        tooltip.set_markup label_for_book(title, authors, publisher, year)
      end
    end
  end

  def label_for_book(title, authors, publisher, year)
    # This is much too complex... but it works for now!
    html = ''
    unless title.empty?
      html += "<b>#{CGI.escapeHTML(title)}</b>"
      unless authors.empty?
        html += "\n"
      end
    end
    unless authors.empty?
      html += "<i>#{CGI.escapeHTML(authors)}</i>"
    end
    if !title.empty? || !authors.empty?
      html += "\n"
    end

    html += '<small>'
    if publisher && !publisher.empty?
      html += "#{CGI.escapeHTML(publisher)}"
    end

    if year && !year.empty?
      if publisher && !publisher.empty?
        html += ' '
      end
      html += "(#{year})"
    end

    html + '</small>'
  end
end
