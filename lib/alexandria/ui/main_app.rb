# Copyright (C) 2004-2006 Laurent Sansonetti
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

class Gtk::ActionGroup
    def [](x)
        get_action(x)
    end
end

class Gtk::IconView
    def freeze
        @old_model = self.model
        self.model = nil
    end

    def unfreeze
        self.model = @old_model
    end
end

class Alexandria::Library
    def action_name
        "MoveIn" + name.gsub(/\s/, '')
    end
end

class Alexandria::BookProviders::AbstractProvider
    def action_name
        "At" + name    
    end
end

module Alexandria
module UI
    class ConflictWhileCopyingDialog < AlertDialog
        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        def initialize(parent, library, book)
            super(parent, 
                  _("The book '%s' already exists in '%s'. Would you like " +
                    "to replace it?") % [ book.title, library.name ],
                  Gtk::Stock::DIALOG_QUESTION,
                  [[_("_Skip"), Gtk::Dialog::RESPONSE_CANCEL],
                   [_("_Replace"), Gtk::Dialog::RESPONSE_OK]],
                  _("If you replace the existing book, its contents will " +
                    "be overwritten."))
            self.default_response = Gtk::Dialog::RESPONSE_CANCEL
            show_all and @response = run
            destroy
        end

        def replace?
            @response == Gtk::Dialog::RESPONSE_OK
        end
    end

    class ReallyDeleteDialog < AlertDialog
        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")
        
        def initialize(parent, library, books=nil)
            # Deleting a library.
            if books.nil?
                message = _("Are you sure you want to delete '%s'?") \
                    % library.name
                description = if library.is_a?(SmartLibrary) \
                                 or library.empty?
                    nil
                else
                    n_("If you continue, %d book will be deleted.",
                       "If you continue, %d books will be deleted.", 
                       library.size) % library.size
                end
            # Deleting books.
            else
                message = if books.length == 1
                    _("Are you sure you want to delete '%s' " +
                      "from '%s'?") % [ books.first.title, library.name ]
                else
                    _("Are you sure you want to delete the " +
                      "selected books from '%s'?") % library.name
                end
                description = nil
            end

            super(parent, message, Gtk::Stock::DIALOG_QUESTION,
                  [[Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                   [Gtk::Stock::DELETE, Gtk::Dialog::RESPONSE_OK]],
                  description)

            self.default_response = Gtk::Dialog::RESPONSE_CANCEL
            show_all and @response = run
            destroy
        end

        def ok?
            @response == Gtk::Dialog::RESPONSE_OK
        end
    end

    class MainApp < GladeBase 
        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        module Columns
            COVER_LIST, COVER_ICON, TITLE, TITLE_REDUCED, AUTHORS,
                ISBN, PUBLISHER, PUBLISH_DATE, EDITION, RATING, IDENT, 
                NOTES = (0..12).to_a
        end

        # The maximum number of rating stars displayed.
        MAX_STARS = 5

        def initialize
            super("main_app.glade")
            @prefs = Preferences.instance
            load_libraries
            initialize_ui
            on_books_selection_changed
            restore_preferences
        end

        def on_library_button_press_event(widget, event)
            # right click
            if event.event_type == Gdk::Event::BUTTON_PRESS and
               event.button == 3

                menu = widget.get_path_at_pos(event.x, event.y) == nil \
                    ? @nolibrary_popup \
                    : selected_library.is_a?(SmartLibrary) \
                        ? @smart_library_popup : @library_popup

                menu.popup(nil, nil, event.button, event.time) 
            end
        end
        
        def on_books_button_press_event(widget, event)
            # right click
            if event.event_type == Gdk::Event::BUTTON_PRESS and
               event.button == 3

                widget.grab_focus

                if path = widget.get_path_at_pos(event.x, event.y)
                    obj, path = widget.is_a?(Gtk::TreeView) \
                        ? [widget.selection, path.first] : [widget, path]

                    unless obj.path_is_selected?(path)
                        widget.unselect_all
                        obj.select_path(path)
                    end
                else
                    widget.unselect_all
                end

                menu = (selected_books.empty?) ? @nobook_popup : @book_popup
                menu.popup(nil, nil, event.button, event.time)
            end
        end

        def on_books_selection_changed
            library = selected_library
            books = selected_books
            @appbar.status = case books.length
                when 0
                    case library.length
                        when 0
                            _("Library '%s' selected") % library.name        
                                
                        else
                            n_unrated = library.n_unrated
                            if n_unrated == library.length
                                n_("Library '%s' selected, %d unrated book",
                                   "Library '%s' selected, %d unrated books",
                                   library.length) % [ library.name,
                                                       library.length ]
                            elsif n_unrated == 0
                                n_("Library '%s' selected, %d book", 
                                   "Library '%s' selected, %d books", 
                                   library.length) % [ library.name, 
                                                       library.length ]
                            else
                                n_("Library '%s' selected, %d book, " +
                                   "%d unrated",
                                   "Library '%s' selected, %d books, " +
                                   "%d unrated",
                                   library.length) % [ library.name, 
                                                       library.length,
                                                       n_unrated ]
                            end
                    end
                when 1
                    _("'%s' selected") % books.first.title
                else
                    n_("%d book selected", "%d books selected", 
                       books.length) % books.length
            end
            unless @library_listview.has_focus?
                @actiongroup["Properties"].sensitive = \
                    @actiongroup["OnlineInformation"].sensitive = \
                    books.length == 1
                @actiongroup["SelectAll"].sensitive = \
                    books.length < library.length
                @actiongroup["Delete"].sensitive = \
                    @actiongroup["DeselectAll"].sensitive = \
                    @actiongroup["Move"].sensitive = 
                    @actiongroup["SetRating"].sensitive = !books.empty?
               
                if library.is_a?(SmartLibrary)
                    @actiongroup["Delete"].sensitive = 
                        @actiongroup["Move"].sensitive = false
                end
 
                # Sensitize providers URL
                if books.length == 1
                    all_url = false
                    BookProviders.each do |provider|
                        has_url = provider.url(books.first) != nil
                        @actiongroup[provider.action_name].sensitive = has_url
                        all_url = true if has_url and !all_url
                    end
                    unless all_url
                        @actiongroup["OnlineInformation"].sensitive = false
                    end
                end
            end
        end

        def on_switch_page
            @actiongroup["ArrangeIcons"].sensitive = @notebook.page == 0
            on_books_selection_changed
        end
        
        def on_focus(widget, event_focus)
            if widget == @library_listview
                %w{OnlineInformation SelectAll DeselectAll}.each do |action| 
                    @actiongroup[action].sensitive = false
                end
                @actiongroup["Properties"].sensitive = 
                    selected_library.is_a?(SmartLibrary)
                @actiongroup["Delete"].sensitive = 
                    (@libraries.all_regular_libraries.length > 1 or 
                        selected_library.is_a?(SmartLibrary)) 
            else
                on_books_selection_changed
            end
        end

        def on_refresh  
            load_libraries
            refresh_libraries
            refresh_books
        end

        def on_close_sidepane
            @actiongroup["Sidepane"].active = false
        end

        def update(*ary)
            caller = ary.first
            if caller.is_a?(UndoManager)
                @actiongroup["Undo"].sensitive = caller.can_undo? 
                @actiongroup["Redo"].sensitive = caller.can_redo?
            elsif caller.is_a?(Library)
                library, kind, book = ary
                if library == selected_library
                    @iconview.freeze
                    case kind 
                        when Library::BOOK_ADDED
                            append_book(book)
         
                        when Library::BOOK_UPDATED
                            iter = iter_from_ident(book.saved_ident)
                            fill_iter_with_book(iter, book)
        
                        when Library::BOOK_REMOVED
                            @model.remove(iter_from_book(book))
                    end
                    @iconview.unfreeze
                elsif selected_library.is_a?(SmartLibrary)
                    refresh_books
                end 
            else
                raise "unrecognized update event"
            end
        end

        #######
        private
        #######

        def display_help
            Gnome::Help.display('alexandria', 
                                nil) rescue ErrorDialog.new(@main_app, 
                                                            e.message)
        end

        def open_web_browser(url)
            unless (cmd = Preferences.instance.www_browser).nil?
                Thread.new { system(cmd % "\"" + url + "\"") }
            else 
                ErrorDialog.new(@main_app,
                                _("Unable to launch the web browser"),
                                _("Check out that a web browser is " +
                                  "configured as default (Desktop " +
                                  "Preferences -> Advanced -> Preferred " +
                                  "Applications) and try again."))
            end
        end

        def open_email_client(url)
            unless (cmd = Preferences.instance.email_client).nil?
                Thread.new { system(cmd % "\"" + url + "\"") }
            else 
                ErrorDialog.new(@main_app,
                                _("Unable to launch the mail reader"),
                                _("Check out that a mail reader is " +
                                  "configured as default (Desktop " +
                                  "Preferences -> Advanced -> Preferred " +
                                  "Applications) and try again."))
            end
        end

        def load_libraries
            completion_models = CompletionModels.instance
            if @libraries
                @libraries.all_regular_libraries.each do |library|
                    if library.is_a?(Library) 
                        library.delete_observer(self)
                        completion_models.remove_source(library)
                    end
                end
                @libraries.reload
            else
                @libraries = Libraries.instance
                @libraries.reload
            end
            @libraries.all_regular_libraries.each do |library| 
                library.add_observer(self)
                completion_models.add_source(library)
            end
        end

        def cache_scaled_icon(icon, width, height)
            @cache ||= {}
            @cache[[icon, width, height]] ||= icon.scale(width, height)
        end

        ICON_TITLE_MAXLEN = 20   # characters
        ICON_WIDTH = 60
        ICON_HEIGHT = 90         # pixels
        REDUCE_TITLE_REGEX = /^(.{#{ICON_TITLE_MAXLEN}}).*$/
        def fill_iter_with_book(iter, book)
            iter[Columns::IDENT] = book.ident
            iter[Columns::TITLE] = book.title
            title = book.title.sub(REDUCE_TITLE_REGEX, '\1...')
            iter[Columns::TITLE_REDUCED] = title
            iter[Columns::AUTHORS] = book.authors.join(', ')
            iter[Columns::ISBN] = book.isbn
            iter[Columns::PUBLISHER] = book.publisher
            iter[Columns::PUBLISH_DATE] = (book.publishing_year.to_s rescue "")
            iter[Columns::EDITION] = book.edition
            iter[Columns::NOTES] = (book.notes or "")
            rating = (book.rating or Book::DEFAULT_RATING)
            iter[Columns::RATING] = 5 - rating # ascending order is the default

            icon = Icons.cover(selected_library, book)
            iter[Columns::COVER_LIST] = cache_scaled_icon(icon, 20, 25)

            if icon.height > ICON_HEIGHT
                new_width = icon.width / (icon.height / ICON_HEIGHT.to_f)
                new_height = [ICON_HEIGHT, icon.height].min
                icon = cache_scaled_icon(icon, new_width, new_height)
            end
            if rating == 5
                icon = icon.tag(Icons::FAVORITE_TAG)
            end
            iter[Columns::COVER_ICON] = icon
        end

        def append_book(book, tail=nil)
            iter = tail ? @model.insert_after(tail) : @model.append
            fill_iter_with_book(iter, book)
            return iter
        end

        def append_library(library, autoselect=false)
            model = @library_listview.model
            is_smart = library.is_a?(SmartLibrary)
            if is_smart 
                if @library_separator_iter.nil?
                    @library_separator_iter = append_library_separator
                end
                iter = model.append
            else
                iter = if @library_separator_iter.nil?
                    model.append
                else
                    model.insert_before(@library_separator_iter) 
                end
            end

            iter[0] = is_smart \
                        ? Icons::SMART_LIBRARY_SMALL : Icons::LIBRARY_SMALL
            iter[1] = library.name
            iter[2] = true      # editable?
            iter[3] = false     # separator?
            if autoselect
                @library_listview.set_cursor(iter.path, 
                                             @library_listview.get_column(0), 
                                             true)
                @actiongroup["Sidepane"].active = true
            end
            return iter
        end
        
        def append_library_separator
            iter = @library_listview.model.append
            iter[0] = nil
            iter[1] = nil
            iter[2] = false     # editable?
            iter[3] = true      # separator?
            return iter
        end

        BADGE_MARKUP = "<span weight=\"heavy\" foreground=\"white\">%d</span>"
        BOOKS_TARGET_TABLE = [["ALEXANDRIA_BOOKS", 
                               Gtk::Drag::TARGET_SAME_APP, 
                               0]]
        def setup_view_source_dnd(view)
            view.signal_connect_after('drag-begin') do |widget, drag_context|
                n_books = selected_books.length
                if n_books > 1
                    # Render generic book icon.
                    pixmap, mask = Icons::BOOK_ICON.render_pixmap_and_mask(255)
                
                    # Create number badge.
                    context = Gdk::Pango.context
                    layout = Pango::Layout.new(context)
                    layout.markup = BADGE_MARKUP % n_books 
                    width, height = layout.pixel_size
                    x = Icons::BOOK_ICON.width - width - 11
                    y = Icons::BOOK_ICON.height - height - 11
            
                    # Draw a red ellipse where the badge number should be.
                    red_gc = Gdk::GC.new(pixmap)
                    red_gc.rgb_fg_color = Gdk::Color.parse('red')
                    red_gc.rgb_bg_color = Gdk::Color.parse('red')
                    pixmap.draw_arc(red_gc,
                                    true,
                                    x - 5, y - 2, 
                                    width + 9, height + 4,
                                    0, 360 * 64)
            
                    # Draw the number badge.
                    pixmap.draw_layout(Gdk::GC.new(pixmap), x, y, layout)
                    
                    # And set the drag icon.
                    Gtk::Drag.set_icon(drag_context, 
                                       pixmap.colormap, 
                                       pixmap,
                                       mask, 
                                       10, 
                                       10)
                end
            end 
        
            view.signal_connect('drag-data-get') do |widget, drag_context,
                                                     selection_data, info,
                                                     time|
            
                idents = selected_books.map { |book| book.ident }
                unless idents.empty?
                    selection_data.set(Gdk::Selection::TYPE_STRING,
                                       idents.join(','))
                end
            end
           
            view.enable_model_drag_source(Gdk::Window::BUTTON1_MASK, 
                                          BOOKS_TARGET_TABLE,
                                          Gdk::DragContext::ACTION_MOVE)
        end

        def setup_books_iconview
            @iconview.model = @iconview_model
            @iconview.selection_mode = Gtk::SELECTION_MULTIPLE
            @iconview.text_column = Columns::TITLE_REDUCED 
            @iconview.pixbuf_column = Columns::COVER_ICON
            @iconview.orientation = Gtk::ORIENTATION_VERTICAL
            @iconview.row_spacing = 4
            @iconview.column_spacing = 16
            @iconview.item_width = ICON_WIDTH + 16
         
            @iconview.signal_connect('selection-changed') do 
                on_books_selection_changed
            end

            @iconview.signal_connect('item-activated') do 
                # Dirty hack to avoid the beginning of a drag within this 
                # handler. 
                Gtk.timeout_add(100) do
                    @actiongroup["Properties"].activate
                    false
                end
            end

            # DND support for Gtk::IconView is shipped since GTK+ 2.8.0.
            if @iconview.respond_to?(:enable_model_drag_source)
                setup_view_source_dnd(@iconview)
            end
        end

        ICONS_SORTS = [
            Columns::TITLE, Columns::AUTHORS, Columns::ISBN, 
            Columns::PUBLISHER, Columns::EDITION, Columns::RATING
        ]
        def setup_books_iconview_sorting
            mode = ICONS_SORTS[@prefs.arrange_icons_mode]
            @iconview_model.set_sort_column_id(mode,
                                               @prefs.reverse_icons \
                                                   ? Gtk::SORT_DESCENDING \
                                                   : Gtk::SORT_ASCENDING)
            @filtered_model.refilter    # force redraw
        end

        def setup_books_listview
            # first column
            @listview.model = @listview_model
            renderer = Gtk::CellRendererPixbuf.new
            title = _("Title")
            column = Gtk::TreeViewColumn.new(title)
            column.widget = Gtk::Label.new(title).show
            column.pack_start(renderer, false)
            column.set_cell_data_func(renderer) do |column, cell, model, iter|
                iter = @listview_model.convert_iter_to_child_iter(iter)
                iter = @filtered_model.convert_iter_to_child_iter(iter)
                cell.pixbuf = iter[Columns::COVER_LIST]
            end        
            renderer = Gtk::CellRendererText.new
            renderer.ellipsize = Pango::ELLIPSIZE_END if Pango.ellipsizable?
=begin
            # Editable tree views are behaving strangely
            renderer.signal_connect('editing_started') do |cell, entry, 
                                                           path_string|
                entry.complete_titles
            end
            renderer.signal_connect('edited') do |cell, path_string, new_string|
                path = Gtk::TreePath.new(path_string)
                path = @listview_model.convert_path_to_child_path(path)
                path = @filtered_model.convert_path_to_child_path(path)
                iter = @model.get_iter(path)
                book = book_from_iter(selected_library, iter)
                book.title = new_string
                @iconview.freeze
                fill_iter_with_book(iter, book)
                @iconview.unfreeze
            end
=end
            column.pack_start(renderer, true)
            column.set_cell_data_func(renderer) do |column, cell, model, iter|
                iter = @listview_model.convert_iter_to_child_iter(iter)
                iter = @filtered_model.convert_iter_to_child_iter(iter)
                cell.text, cell.editable = iter[Columns::TITLE], false #true
            end
            column.sort_column_id = Columns::TITLE 
            column.resizable = true
            @listview.append_column(column)

            # other columns
            names = [ 
                [ _("Authors"), Columns::AUTHORS ],
                [ _("ISBN"), Columns::ISBN ],
                [ _("Publisher"), Columns::PUBLISHER ],
                [ _("Publish Year"), Columns::PUBLISH_DATE ],
                [ _("Binding"), Columns::EDITION ]
            ]
            names.each do |title, iterid|
                renderer = Gtk::CellRendererText.new
                renderer.ellipsize = Pango::ELLIPSIZE_END if Pango.ellipsizable?
                column = Gtk::TreeViewColumn.new(title, renderer,
                                                 :text => iterid)
                column.widget = Gtk::Label.new(title).show
                column.sort_column_id = iterid
                column.resizable = true
                @listview.append_column(column)
            end

            # final column
            title = _("Rating")
            column = Gtk::TreeViewColumn.new(title)
            column.widget = Gtk::Label.new(title).show
            column.sizing = Gtk::TreeViewColumn::FIXED
            column.fixed_width = column.min_width = column.max_width =
                (Icons::STAR_SET.width + 1) * MAX_STARS
            MAX_STARS.times do |i|
                renderer = Gtk::CellRendererPixbuf.new
                column.pack_start(renderer, false)
                column.set_cell_data_func(renderer) do |column, cell, 
                                                        model, iter|
                    iter = @listview_model.convert_iter_to_child_iter(iter)
                    iter = @filtered_model.convert_iter_to_child_iter(iter)
                    rating = (iter[Columns::RATING] - MAX_STARS).abs
                    cell.pixbuf = rating >= i.succ ? 
                        Icons::STAR_SET : Icons::STAR_UNSET
                end
            end
            column.sort_column_id = Columns::RATING
            column.resizable = false 
            @listview.append_column(column)

            @listview.selection.mode = Gtk::SELECTION_MULTIPLE
            @listview.selection.signal_connect('changed') do 
                on_books_selection_changed
            end
            
            @listview.signal_connect('row-activated') do
                # Dirty hack to avoid the beginning of a drag within this 
                # handler. 
                Gtk.timeout_add(100) do
                    @actiongroup["Properties"].activate
                    false
                end
            end

            setup_view_source_dnd(@listview)
        end

        def setup_listview_columns_visibility
            # Show or hide list view columns according to the preferences. 
            cols_visibility = [
                @prefs.col_authors_visible,
                @prefs.col_isbn_visible,
                @prefs.col_publisher_visible,
                @prefs.col_publish_date_visible,
                @prefs.col_edition_visible,
                @prefs.col_rating_visible
            ]
            cols = @listview.columns[1..-1] # skip "Title"
            cols.each_index do |i|
                cols[i].visible = cols_visibility[i]
            end
        end

        # Sets the width of each column based on any respective
        # preference value stored.
        def setup_listview_columns_width
            if @prefs.cols_width
                cols_width = YAML.load(@prefs.cols_width)
                @listview.columns.each do |c|
                    if cols_width.has_key?(c.title)
                        c.sizing = Gtk::TreeViewColumn::FIXED
                        c.fixed_width = cols_width[c.title]
                    end
                end
            end
        end
 
        def refresh_books
            # Clear the views.
            library = selected_library
            @model.clear
            @iconview.freeze
            @model.freeze_notify do
                tail = nil
                library.each { |book| tail = append_book(book, tail) }
            end
            @filtered_model.refilter
            @iconview.unfreeze
            @listview.columns_autosize

=begin      
            # Append books - we do that in a separate thread.
            library = selected_library
            @appbar.progress_percentage = 0
            @appbar.children.first.visible = true   # show the progress bar
            @appbar.status = _("Loading '%s'...") % library.name
            exec_queue = ExecutionQueue.new
            
            on_progress = proc do |percent|
                @appbar.progress_percentage = percent
            end
            
            thread = Thread.start do
                total = library.length
                library.each_with_index do |book, n|
                    append_book(book)
                    # convert to percents
                    coeff = total / 100.0
                    percent = n / coeff
                    fraction = percent / 100
                    #puts "#index #{n} percent #{percent} fraction #{fraction}"
                    exec_queue.call(on_progress, fraction)
                end
            end

            while thread.alive?
                exec_queue.iterate
                Gtk.main_iteration_do(false)
            end
 
            @appbar.progress_percentage = 1 
=end           

            # Hide the progress bar.
            @appbar.children.first.visible = false
            
            # Refresh the status bar.
            on_books_selection_changed
        end
        
        def selected_library
            if iter = @library_listview.selection.selected
                @libraries.all_libraries.find { |x| x.name == iter[1] }
            else
                @libraries.all_libraries.first
            end
        end
   
        def select_library(library)
            iter = @library_listview.model.iter_first
            ok = true
            while ok do
                if iter[1] == library.name
                    @library_listview.selection.select_iter(iter)
                    break 
                end
                ok = iter.next!
            end
        end

        def book_from_iter(library, iter)
            library.find { |x| x.ident == iter[Columns::IDENT] }
        end

        def iter_from_ident(ident)
            iter = @model.iter_first
            ok = true
            while ok do
                if iter[Columns::IDENT] == ident
                    return iter
                end
                ok = iter.next!
            end
            return nil
        end

        def iter_from_book(book)
            iter_from_ident(book.ident)
        end
        
        def selected_books
            a = []
            library = selected_library
            view = case @notebook.page
                when 0
                    @iconview.selected_each do |iconview, path|
                        path = @iconview_model.convert_path_to_child_path(path)
                        path = @filtered_model.convert_path_to_child_path(path)
                        iter = @model.get_iter(path)
                        a << book_from_iter(library, iter)
                    end

                when 1
                    @listview.selection.selected_each do |model, path, 
                                                          iter|
                        path = @listview_model.convert_path_to_child_path(path)
                        path = @filtered_model.convert_path_to_child_path(path)
                        iter = @model.get_iter(path)
                        a << book_from_iter(library, iter)
                    end
            end
            a.select { |x| x != nil }
        end   

        def setup_sidepane
            @library_listview.model = Gtk::ListStore.new(Gdk::Pixbuf, 
                                                         String, 
                                                         TrueClass,
                                                         TrueClass)
            @library_separator_iter = nil
            @libraries.all_regular_libraries.each { |x| append_library(x) }
            @libraries.all_smart_libraries.each { |x| append_library(x) }

            renderer = Gtk::CellRendererPixbuf.new
            column = Gtk::TreeViewColumn.new(_("Library"))
            column.pack_start(renderer, false)
            column.set_cell_data_func(renderer) do |column, cell, model, iter|
                cell.pixbuf = iter[0]
            end        
            renderer = Gtk::CellRendererText.new
            renderer.ellipsize = Pango::ELLIPSIZE_END if Pango.ellipsizable?
            column.pack_start(renderer, true) 
            column.set_cell_data_func(renderer) do |column, cell, model, iter|
                cell.text, cell.editable = iter[1], iter[2]
            end
            renderer.signal_connect('edited') do |cell, path_string, new_text|
                if cell.text != new_text
                    if match = /([^\w\s'"()?!:;.\-])/.match(new_text)
                        ErrorDialog.new(@main_app,
                                        _("Invalid library name '%s'") % 
                                          new_text,
                                        _("The name provided contains the " +
                                          "illegal character '<i>%s</i>'.") % 
                                          match[1])
                    elsif new_text.strip.empty?
                        ErrorDialog.new(@main_app, _("The library name " +
                                                     "can not be empty"))
                    elsif x = (@libraries.all_libraries + 
                               Library.deleted_libraries).find { 
                                |library| library.name == new_text.strip } \
                       and x.name != selected_library.name
                        ErrorDialog.new(@main_app, 
                                        _("The library can not be renamed"),
                                        _("There is already a library named " +
                                          "'%s'.  Please choose a different " +
                                          "name.") % new_text.strip)
                    else
                        path = Gtk::TreePath.new(path_string)
                        iter = @library_listview.model.get_iter(path)
                        iter[1] = selected_library.name = new_text.strip
                        setup_move_actions
                        refresh_libraries
                    end
                end
            end
            @library_listview.append_column(column)

            @library_listview.set_row_separator_func { |model, iter| iter[3] }

            @library_listview.selection.signal_connect('changed') do 
                refresh_libraries
                refresh_books
            end

            @library_listview.enable_model_drag_dest(
                BOOKS_TARGET_TABLE,
                Gdk::DragContext::ACTION_MOVE)

            @library_listview.signal_connect('drag-motion') do 
                |widget, drag_context, x, y, time, data|

                path, column, cell_x, cell_y = 
                    @library_listview.get_path_at_pos(x, y)

                if path 
                    # Refuse drags from/to smart libraries.
                    if selected_library.is_a?(SmartLibrary)
                        path = nil
                    else
                        iter = @library_listview.model.get_iter(path)
                        if iter[3]  # separator?
                            path = nil
                        else
                            library = @libraries.all_libraries.find do |x| 
                                x.name == iter[1]
                            end
                            path = nil if library.is_a?(SmartLibrary)
                        end
                    end
                end

                @library_listview.set_drag_dest_row(
                    path, 
                    Gtk::TreeView::DROP_INTO_OR_AFTER)

                drag_context.drag_status(
                    path != nil ? drag_context.suggested_action : 0, 
                    time)
            end
 
            @library_listview.signal_connect('drag-drop') do 
                |widget, drag_context, x, y, time, data|

                Gtk::Drag.get_data(widget, 
                                   drag_context, 
                                   drag_context.targets.first,
                                   time)
                true
            end

            @library_listview.signal_connect('drag-data-received') do 
                |widget, drag_context, x, y, selection_data, info, time|

                success = false
                if selection_data.type == Gdk::Selection::TYPE_STRING
                    path, position = 
                        @library_listview.get_dest_row_at_pos(x, y)

                    if path
                        iter = @library_listview.model.get_iter(path)
                        library = @libraries.all_libraries.find do |x| 
                            x.name == iter[1]
                        end
                        move_selected_books_to_library(library)
                    end
                end
                Gtk::Drag.finish(drag_context, success, false, time)
            end
        end

        def refresh_libraries
            library = selected_library
            
            # Change the application's title.
            @main_app.title = library.name + " - " + TITLE
           
            # Disable the selected library in the move libraries actions.
            @libraries.all_regular_libraries.each do |i_library|
                action = @actiongroup[i_library.action_name]
                action.sensitive = i_library != library if action
            end

            # Disable some actions if we selected a smart library.
            smart = library.is_a?(SmartLibrary)
            @actiongroup["AddBook"].sensitive = !smart
            @actiongroup["AddBookManual"].sensitive = !smart
            @actiongroup["Properties"].sensitive = smart
            @actiongroup["Delete"].sensitive = 
                (@libraries.all_regular_libraries.length > 1 or smart) 
        end

        def restore_preferences
            if @prefs.maximized
                @main_app.maximize
            else
                @main_app.move(*@prefs.position) \
                    unless @prefs.position == [0, 0] 
                @main_app.resize(*@prefs.size)
                @maximized = false
            end
            @paned.position = @prefs.sidepane_position
            @actiongroup["Sidepane"].active = @prefs.sidepane_visible
            @actiongroup["Toolbar"].active = @prefs.toolbar_visible
            @actiongroup["Statusbar"].active = @prefs.statusbar_visible 
            @appbar.visible = @prefs.statusbar_visible 
            action = case @prefs.view_as
                when 0
                    @actiongroup["AsIcons"]
                when 1
                    @actiongroup["AsList"]
            end
            action.activate
            library = nil
            unless @prefs.selected_library.nil?
                library = @libraries.all_libraries.find do |x|
                    x.name == @prefs.selected_library
                end
            end
            if library
                select_library(library)
            else
                # Select the first item by default.
                iter = @library_listview.model.iter_first
                @library_listview.selection.select_iter(iter)
            end
        end

        def save_preferences
            @prefs.position = @main_app.position
            @prefs.size = @main_app.allocation.to_a[2..3]
            @prefs.maximized = @maximized
            @prefs.sidepane_position = @paned.position
            @prefs.sidepane_visible = @actiongroup["Sidepane"].active?
            @prefs.toolbar_visible = @actiongroup["Toolbar"].active? 
            @prefs.statusbar_visible = @actiongroup["Statusbar"].active?
            @prefs.view_as = @notebook.page
            @prefs.selected_library = selected_library.name
            cols_width = Hash.new
            @listview.columns.each do |c|
                cols_width[c.title] = [c.widget.size_request.first, c.width].max
            end
            @prefs.cols_width = '{' + cols_width.to_a.collect do |t, v|
                '"' + t + '": ' + v.to_s
            end.join(', ') + '}'
        end 
     
        def undoable_move(source, dest, books)
            Library.move(source, dest, *books)
            UndoManager.instance.push { undoable_move(dest, source, books) }
        end
 
        def move_selected_books_to_library(library)
            books = selected_books.select do |book|
                !library.include?(book) or 
                    ConflictWhileCopyingDialog.new(@main_app, 
                                                   library,
                                                   book).replace?
            end
            undoable_move(selected_library, library, books)
        end

        def setup_move_actions
            @actiongroup.actions.each do |action|
                next unless /^MoveIn/.match(action.name)
                @actiongroup.remove_action(action)
            end
            actions = []
            @libraries.all_regular_libraries.each do |library|
                actions << [ 
                    library.action_name, nil,
                    _("In '_%s'") % library.name, 
                    nil, nil, proc { move_selected_books_to_library(library) }
                ]
            end
            @actiongroup.add_actions(actions)
            @uimanager.remove_ui(@move_mid) if @move_mid
            @move_mid = @uimanager.new_merge_id 
            @libraries.all_regular_libraries.each do |library|
                name = library.action_name
                [ "ui/MainMenubar/EditMenu/Move/",
                  "ui/BookPopup/Move/" ].each do |path|
                    @uimanager.add_ui(@move_mid, path, name, name,
                                      Gtk::UIManager::MENUITEM, false)
                end
            end
        end
        
        def undoable_delete(library, books=nil)        
            # Deleting a library.
            if books.nil?
                library.delete_observer(self) if library.is_a?(Library)
                library.delete
                @libraries.remove_library(library)
                if @library_separator_iter != nil and 
                   @libraries.all_smart_libraries.empty?
               
                    @library_listview.model.remove(@library_separator_iter)
                    @library_separator_iter = nil
                end
                previous_selected_library = selected_library
                if previous_selected_library != library 
                    select_library(library) 
                else
                    previous_selected_library = nil
                end
                iter = @library_listview.selection.selected
                next_iter = @library_listview.selection.selected
                next_iter.next!
                @library_listview.model.remove(iter)
                @library_listview.selection.select_iter(next_iter)
                setup_move_actions
                select_library(previous_selected_library) \
                    unless previous_selected_library.nil?
            # Deleting books.
            else
               books.each { |book| library.delete(book) }
            end
            UndoManager.instance.push { undoable_undelete(library, books) }
        end

        def undoable_undelete(library, books=nil)
            # Undeleting a library.
            if books.nil?
                library.undelete
                @libraries.add_library(library)
                append_library(library)
                setup_move_actions
                library.add_observer(self) if library.is_a?(Library)
            # Undeleting books. 
            else
                books.each { |book| library.undelete(book) }
            end
            select_library(library)
            UndoManager.instance.push { undoable_delete(library, books) }
        end

        def initialize_ui
            @main_app.icon = Icons::ALEXANDRIA_SMALL

            on_new = proc do
                name = Library.generate_new_name(@libraries.all_libraries)
                library = Library.load(name)
                @libraries.add_library(library)
                append_library(library, true)
                setup_move_actions
                library.add_observer(self)
            end
   
            on_new_smart = proc do
                NewSmartLibraryDialog.new(@main_app) do |smart_library|
                    smart_library.refilter
                    @libraries.add_library(smart_library)
                    append_library(smart_library, true)
                    smart_library.save
                end
            end
 
            on_add_book = proc do
                NewBookDialog.new(@main_app, 
                                  selected_library) do |books, library, is_new|
                    if is_new
                        append_library(library, true)
                        setup_move_actions
                    elsif selected_library != library
                        select_library(library)
                    end
                end
            end
     
            on_add_book_manual = proc do
                library = selected_library
                NewBookDialogManual.new(@main_app, library) { |book| }
            end
            
            on_import = proc do 
                ImportDialog.new(@main_app) do |library|
                    @libraries.add_library(library)
                    append_library(library, true)
                    setup_move_actions
                end
            end

            on_export = proc { ExportDialog.new(@main_app, selected_library) }
        
            on_acquire = proc do
                AcquireDialog.new(@main_app, 
                                  selected_library) do |books, library, is_new|
                    if is_new
                        append_library(library, true)
                        setup_move_actions
                    elsif selected_library != library
                        select_library(library)
                    end
                end
            end 

            on_properties = proc do
                if @library_listview.focus?
                    library = selected_library
                    if library.is_a?(SmartLibrary)
                        SmartLibraryPropertiesDialog.new(@main_app,
                                                         library) do
                            library.refilter
                            refresh_books
                        end 
                    end
                else
                    books = selected_books
                    if books.length == 1
                        book = books.first
                        BookPropertiesDialog.new(@main_app,
                                                 selected_library, 
                                                 book) { |modified_book| }
                    end
                end
            end

            on_quit = proc do
                save_preferences
                Gtk.main_quit
                @libraries.really_delete_deleted_libraries
                @libraries.all_regular_libraries.each do |library|
                    library.really_delete_deleted_books
                end
            end
  
            on_undo = proc { UndoManager.instance.undo! } 
            on_redo = proc { UndoManager.instance.redo! } 
 
            on_select_all = proc do
                case @notebook.page
                    when 0
                        @iconview.select_all
                    when 1
                        @listview.selection.select_all
                end
            end
            
            on_deselect_all = proc do
                case @notebook.page
                    when 0
                        @iconview.unselect_all
                    when 1
                        @listview.selection.unselect_all
                end
            end

            on_set_rating = (0..5).map do |rating|
                proc do 
                    books = selected_books
                    library = selected_library
                    books.each do |book| 
                        book.rating = rating
                        library.save(book)
                    end
                end
            end

            on_rename = proc do
                iter = @library_listview.selection.selected
                @library_listview.set_cursor(iter.path, 
                                             @library_listview.get_column(0), 
                                             true)
            end

            on_delete = proc do
                library = selected_library
                books = @library_listview.focus? ? nil : selected_books
                if library.empty? or ReallyDeleteDialog.new(@main_app, 
                                                            library, 
                                                            books).ok?
                    undoable_delete(library, books)
                end
            end
     
            on_clear_search_results = proc do
                @filter_entry.text = ""
                @iconview.freeze
                @filtered_model.refilter
                @iconview.unfreeze
            end
    
            on_search = proc { @filter_entry.grab_focus }
            on_preferences = proc do
                PreferencesDialog.new(@main_app) do 
                    setup_listview_columns_visibility
                end
            end
            on_submit_bug_report = proc { open_web_browser(BUGREPORT_URL) }
            on_help = proc { display_help }
            on_about = proc { AboutDialog.new(@main_app).show }

            standard_actions = [
                ["LibraryMenu", nil, _("_Library")],
                ["New", Gtk::Stock::NEW, _("_New Library"), "<control>L", 
                 _("Create a new library"), on_new],
                ["NewSmart", nil, _("New _Smart Library..."), 
                 "<control><shift>L", _("Create a new smart library"), 
                 on_new_smart],
                ["AddBook", Gtk::Stock::ADD, _("_Add Book..."), "<control>N", 
                 _("Add a new book from the Internet"), on_add_book],
                ["AddBookManual", nil, _("Add Book _Manually..."), 
                 "<control><shift>N", _("Add a new book manually"), 
                 on_add_book_manual],
                ["Import", nil, _("_Import..."), "<control>I", 
                 _("Import a library"), on_import],
                ["Export", nil, _("_Export..."), "<control><shift>E", 
                 _("Export the selected library"), on_export],
                ["Acquire", nil, _("_Acquire from Scanner..."), nil, 
                 _("Acquire books from a scanner"), on_acquire],
                ["Properties", Gtk::Stock::PROPERTIES, _("_Properties"), nil, 
                 _("Edit the properties of the selected book"), on_properties],
                ["Quit", Gtk::Stock::QUIT, _("_Quit"), "<control>Q", 
                 _("Quit the program"), on_quit],
                ["EditMenu", nil, _("_Edit")],
                ["Undo", Gtk::Stock::UNDO, _("_Undo"), "<control>Z", 
                 _("Undo the last action"), on_undo],
                ["Redo", Gtk::Stock::REDO, _("_Redo"), "<control><shift>Z", 
                 _("Redo the undone action"), on_redo],
                ["SelectAll", nil, _("_Select All"), "<control>A", 
                 _("Select all visible books"), on_select_all],
                ["DeselectAll", nil, _("Dese_lect All"), "<control><shift>A", 
                 _("Deselect everything"), on_deselect_all],
                ["SetRating", nil, _("My _Rating")],
                ["SetRating0", nil, _("None"), nil, nil, on_set_rating[0]],
                ["SetRating1", nil, _("One Star"), nil, nil, 
                 on_set_rating[1]],
                ["SetRating2", nil, _("Two Stars"), nil, nil, 
                 on_set_rating[2]],
                ["SetRating3", nil, _("Three Stars"), nil, nil, 
                 on_set_rating[3]],
                ["SetRating4", nil, _("Four Stars"), nil, nil, 
                 on_set_rating[4]],
                ["SetRating5", nil, _("Five Stars"), nil, nil, 
                 on_set_rating[5]],
                ["Move", nil, _("_Move")],
                ["Rename", nil, _("_Rename"), nil, nil, on_rename],
                ["Delete", Gtk::Stock::DELETE, _("_Delete"), "Delete", 
                 _("Delete the selected books or library"), on_delete],
                ["Search", Gtk::Stock::FIND, _("_Search"), "<control>F", 
                 _("Filter books"), on_search],
                ["ClearSearchResult", Gtk::Stock::CLEAR, _("_Clear Results"), 
                 "<control><alt>B", _("Clear the search results"), 
                 on_clear_search_results],
                ["Preferences", Gtk::Stock::PREFERENCES, _("_Preferences"), 
                 nil, _("Change Alexandria's settings"), on_preferences],
                ["ViewMenu", nil, _("_View")],
                ["Refresh", Gtk::Stock::REFRESH, _("_Refresh"), "<control>R", 
                 _("Reload the selected library"), proc { on_refresh }],
                ["ArrangeIcons", nil, _("Arran_ge Icons")],
                ["OnlineInformation", nil, _("Display Online _Information")],
                ["HelpMenu", nil, _("_Help")],
                ["SubmitBugReport", Gnome::Stock::MAIL_NEW, 
                 _("Submit _Bug Report"), nil, 
                 _("Submit a bug report to the developers"),
                 on_submit_bug_report],
                ["Help", Gtk::Stock::HELP, _("Contents"), "F1", 
                 _("View Alexandria's manual"), on_help],
                ["About", Gtk::Stock::ABOUT, _("_About"), nil, 
                 _("Show information about Alexandria"), on_about],
            ]

            on_view_sidepane = proc do |actiongroup, action| 
                @paned.child1.visible = action.active? 
            end

            on_view_toolbar = proc do |actiongroup, action|
                @toolbar.parent.visible = action.active?
            end

            on_view_statusbar = proc do |actiongroup, action|
                @appbar.visible = action.active?
            end
            
            on_reverse_order = proc do |actiongroup, action|
                Preferences.instance.reverse_icons = action.active? 
                setup_books_iconview_sorting
            end

            toggle_actions = [
                ["Sidepane", nil, _("Side _Pane"), "F9", nil, 
                 on_view_sidepane, true],
                ["Toolbar", nil, _("_Toolbar"), nil, nil, 
                 on_view_toolbar, true],
                ["Statusbar", nil, _("_Statusbar"), nil, nil, 
                 on_view_statusbar, true],
                ["ReversedOrder", nil, _("Re_versed Order"), nil, nil, 
                 on_reverse_order],
            ]
            
            view_as_actions = [
                ["AsIcons", nil, _("View as _Icons"), nil, nil, 0],
                ["AsList", nil, _("View as _List"), nil, nil, 1]
            ]

            arrange_icons_actions = [
                ["ByTitle", nil, _("By _Title"), nil, nil, 0],
                ["ByAuthors", nil, _("By _Authors"), nil, nil, 1],
                ["ByISBN", nil, _("By _ISBN"), nil, nil, 2],
                ["ByPublisher", nil, _("By _Publisher"), nil, nil, 3],
                ["ByEdition", nil, _("By _Binding"), nil, nil, 4],
                ["ByRating", nil, _("By _Rating"), nil, nil, 5]
            ]

            providers_actions = BookProviders.map do |provider|
                [provider.action_name, Gtk::Stock::JUMP_TO, 
                 _("At _%s") % provider.fullname, nil, nil, 
                 proc { open_web_browser(provider.url(selected_books.first)) }]
            end
            
            @actiongroup = Gtk::ActionGroup.new("actions")
            @actiongroup.add_actions(standard_actions)
            @actiongroup.add_actions(providers_actions)
            @actiongroup.add_toggle_actions(toggle_actions)
            @actiongroup.add_radio_actions(view_as_actions) do |action, current|
                @notebook.page = current.current_value
                hid = @toolbar_view_as_signal_hid
                @toolbar_view_as.signal_handler_block(hid) do
                    @toolbar_view_as.active = current.current_value 
                end
            end
            @actiongroup.add_radio_actions(arrange_icons_actions) do |action, 
                                                                      current|
                @prefs.arrange_icons_mode = current.current_value 
                setup_books_iconview_sorting
            end
           
            @uimanager = Gtk::UIManager.new
            @uimanager.insert_action_group(@actiongroup, 0)
            @main_app.add_accel_group(@uimanager.accel_group)
            
            [ "menus.xml", "popups.xml" ].each do |ui_file|
                @uimanager.add_ui(File.join(Alexandria::Config::DATA_DIR, 
                                            "ui", ui_file))
            end

            mid = @uimanager.new_merge_id 
            BookProviders.each do |provider|
                name = provider.action_name    
                [ "ui/MainMenubar/ViewMenu/OnlineInformation/",
                  "ui/BookPopup/OnlineInformation/",
                  "ui/NoBookPopup/OnlineInformation/" ].each do |path|
                    @uimanager.add_ui(mid, path, name, name, 
                                      Gtk::UIManager::MENUITEM, false)
                end
            end

            mid = @uimanager.new_merge_id 
            @uimanager.add_ui(mid, "ui/", "MainToolbar", "MainToolbar", 
                              Gtk::UIManager::TOOLBAR, false)        
            @uimanager.add_ui(mid, "ui/MainToolbar/", "New", "New", 
                              Gtk::UIManager::TOOLITEM, false)        
            @uimanager.add_ui(mid, "ui/MainToolbar/", "AddBook", "AddBook", 
                              Gtk::UIManager::TOOLITEM, false)        
            @uimanager.add_ui(mid, "ui/MainToolbar/", "sep", "sep",
                              Gtk::UIManager::SEPARATOR, false)
            @uimanager.add_ui(mid, "ui/MainToolbar/", "Refresh", "Refresh", 
                              Gtk::UIManager::TOOLITEM, false)        

            @toolbar = @uimanager.get_widget("/MainToolbar")
            @toolbar.show_arrow = true
            @toolbar.insert(-1, Gtk::SeparatorToolItem.new)
            tooltips = Gtk::Tooltips.new 
    
            cb = Gtk::ComboBox.new
            cb.set_row_separator_func do |model, iter|
                iter[0] == '-'
            end
            [ _("Match everything"),
              '-',
              _("Title contains"), 
              _("Authors contain"),
              _("ISBN contains"), 
              _("Publisher contains"),
              _("Notes contain") ].each do |item|
                
                cb.append_text(item)
            end
            cb.active = 0
            cb.signal_connect('changed') do |cb|
                @filter_books_mode = cb.active 
                @filter_entry.text.strip!
                @iconview.freeze
                @filtered_model.refilter
                @iconview.unfreeze
            end
            # Put the combo box in a event box because it is not currently
            # possible assign a tooltip to a combo box.
            eb = Gtk::EventBox.new
            eb << cb
            toolitem = Gtk::ToolItem.new
            toolitem.border_width = 5
            toolitem << eb
            @toolbar.insert(-1, toolitem)
            tooltips.set_tip(eb, _("Change the search type"), nil)

            @filter_entry = Gtk::Entry.new
            @filter_entry.signal_connect('changed') do 
                @filter_entry.text.strip!
                @iconview.freeze
                @filtered_model.refilter
                @iconview.unfreeze
            end
            toolitem = Gtk::ToolItem.new
            toolitem.expand = true
            toolitem.border_width = 5
            tooltips.set_tip(@filter_entry, 
                             _("Type here the search criterion"), nil)
            toolitem << @filter_entry
            @toolbar.insert(-1, toolitem)

            @toolbar.insert(-1, Gtk::SeparatorToolItem.new)
           
            @toolbar_view_as = Gtk::ComboBox.new
            @toolbar_view_as.append_text(_("View as Icons"))
            @toolbar_view_as.append_text(_("View as List"))
            @toolbar_view_as.active = 0
            @toolbar_view_as_signal_hid = \
                @toolbar_view_as.signal_connect('changed') do |cb| 
                    action = case cb.active
                        when 0
                            @actiongroup['AsIcons']
                        when 1
                            @actiongroup['AsList']
                    end
                    action.active = true
                end
            # Put the combo box in a event box because it is not currently
            # possible assign a tooltip to a combo box.
            eb = Gtk::EventBox.new
            eb << @toolbar_view_as 
            toolitem = Gtk::ToolItem.new
            toolitem.border_width = 5 
            toolitem << eb
            @toolbar.insert(-1, toolitem)
            tooltips.set_tip(eb, _("Choose how to show books"), nil)

            @toolbar.show_all
            
            @actiongroup["Undo"].sensitive = 
                @actiongroup["Redo"].sensitive = false
            UndoManager.instance.add_observer(self)
            
            @main_app.toolbar = @toolbar
            @main_app.menus = @uimanager.get_widget("/MainMenubar")
            @library_popup = @uimanager.get_widget("/LibraryPopup") 
            @smart_library_popup = @uimanager.get_widget("/SmartLibraryPopup") 
            @nolibrary_popup = @uimanager.get_widget("/NoLibraryPopup") 
            @book_popup = @uimanager.get_widget("/BookPopup") 
            @nobook_popup = @uimanager.get_widget("/NoBookPopup") 
            
            @main_app.signal_connect('window-state-event') do |w, e|
                if e.is_a?(Gdk::EventWindowState)
                    @maximized = \
                        e.new_window_state == Gdk::EventWindowState::MAXIMIZED 
                end
            end
        
            @main_app.signal_connect('destroy') do 
                @actiongroup["Quit"].activate
            end
            
            Gtk::AboutDialog.set_url_hook do |about, link|
                open_web_browser(link)
            end
            Gtk::AboutDialog.set_email_hook do |about, link|
                open_email_client("mailto:" + link)
            end
 
            # The active model. 
            @model = Gtk::ListStore.new(Gdk::Pixbuf,    # COVER_LIST 
                                        Gdk::Pixbuf,    # COVER_ICON
                                        String,         # TITLE
                                        String,         # TITLE_REDUCED
                                        String,         # AUTHORS
                                        String,         # ISBN
                                        String,         # PUBLISHER
                                        String,         # PUBLISH_DATE
                                        String,         # EDITION
                                        Integer,        # RATING
                                        String,         # IDENT
                                        String)         # NOTES

            # Filter books according to the search toolbar widgets. 
            @filtered_model = Gtk::TreeModelFilter.new(@model)
            @filtered_model.set_visible_func do |model, iter| 
                @filter_books_mode ||= 0
                filter = @filter_entry.text
                if filter.empty?
                    true
                else
                    data = case @filter_books_mode
                        when 0 then 
                            (iter[Columns::TITLE] or "") +
                            (iter[Columns::AUTHORS] or "") +
                            (iter[Columns::ISBN] or "") +
                            (iter[Columns::PUBLISHER] or "") +
                            (iter[Columns::NOTES] or "")
                        when 2 then iter[Columns::TITLE]
                        when 3 then iter[Columns::AUTHORS]
                        when 4 then iter[Columns::ISBN]
                        when 5 then iter[Columns::PUBLISHER]
                        when 6 then iter[Columns::NOTES]
                    end
                    data != nil and data.downcase.include?(filter.downcase)
                end     
            end

            # Give filter entry the initial keyboard focus.
            @filter_entry.grab_focus
            
            @listview_model = Gtk::TreeModelSort.new(@filtered_model)
            @iconview_model = Gtk::TreeModelSort.new(@filtered_model)

            setup_books_listview
            setup_books_iconview
            setup_sidepane
            setup_move_actions
            setup_listview_columns_visibility
            setup_listview_columns_width
        end
    end
end
end
