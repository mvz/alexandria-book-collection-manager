# Copyright (C) 2004 Laurent Sansonetti
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

module Alexandria
module UI
    class BookPropertiesDialogBase < GladeBase
        include GetText
        extend GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        COVER_MAXWIDTH = 140    # pixels
        
        def initialize(parent, cover_file)
            super('book_properties_dialog.glade')
            @book_properties_dialog.transient_for = parent
            @parent, @cover_file = parent, cover_file
            
            @treeview_authors.model = Gtk::ListStore.new(String, TrueClass)
            @treeview_authors.selection.mode = Gtk::SELECTION_SINGLE
            renderer = Gtk::CellRendererText.new
            renderer.signal_connect('edited') do |cell, path_string, new_text|
                path = Gtk::TreePath.new(path_string)
                iter = @treeview_authors.model.get_iter(path)
                iter[0] = new_text 
            end
            col = Gtk::TreeViewColumn.new("", renderer, 
                                          :text => 0, 
                                          :editable => 1)
            @treeview_authors.append_column(col)
        end

        def on_title_changed
            @book_properties_dialog.title = @entry_title.text
        end
        
        def on_add_author
            iter = @treeview_authors.model.append
            iter[0] = _("Author")
            iter[1] = true
            @treeview_authors.set_cursor(iter.path, 
                                         @treeview_authors.get_column(0), 
                                         true)
        end

        def on_remove_author
            if iter = @treeview_authors.selection.selected
	            @treeview_authors.model.remove(iter)
            end
        end
        
        def on_image_rating1_press
            self.rating = 1
        end
        
        def on_image_rating2_press
            self.rating = 2 
        end
        
        def on_image_rating3_press
            self.rating = 3 
        end
        
        def on_image_rating4_press
            self.rating = 4 
        end
        
        def on_image_rating5_press
            self.rating = 5 
        end
       
        def on_change_cover
            backend = `uname`.chomp == "FreeBSD" ? "neant" : "gnome-vfs"
            dialog = Gtk::FileChooserDialog.new(_("Select a cover image"),
                                                @book_properties_dialog,
                                                Gtk::FileChooser::ACTION_OPEN,
                                                backend, 
                                                [Gtk::Stock::CANCEL, 
                                                 Gtk::Dialog::RESPONSE_CANCEL],
                                                [Gtk::Stock::OPEN, 
                                                 Gtk::Dialog::RESPONSE_ACCEPT])
            if dialog.run == Gtk::Dialog::RESPONSE_ACCEPT
                begin
                    cover = Gdk::Pixbuf.new(dialog.filename)
                    # At this stage the file format is recognized.
                    FileUtils.cp(dialog.filename, @cover_file)
                    self.cover = cover
                rescue RuntimeError => e 
                    ErrorDialog.new(@book_properties_dialog, e.message)
                end
            end
            dialog.destroy
        end
       
        def on_destroy; end     # no action by default

        def on_loaned
            loaned = @checkbutton_loaned.active?
            @entry_loaned_to.sensitive = loaned
            @date_loaned_since.sensitive = loaned
            @label_loaning_duration.visible = loaned
        end

        def on_loaned_date_changed
            loaned_time = Time.at(@date_loaned_since.time)
            n_days = (Time.now - loaned_time) / (3600*24)
            if n_days > 1
                @label_loaning_duration.label = _("%d days") % n_days 
            else
                @label_loaning_duration.label = ""
            end
        end
            
        #######
        private
        #######
    
        def rating=(rating)
            images = [ 
                @image_rating1, 
                @image_rating2, 
                @image_rating3, 
                @image_rating4, 
                @image_rating5
            ]
            raise "out of range" if rating < 0 or rating > images.length
            images[0..rating-1].each { |x| x.pixbuf = Icons::STAR_SET }
            images[rating..-1].each { |x| x.pixbuf = Icons::STAR_UNSET }
            @current_rating = rating
        end

        def cover=(pixbuf)
            if pixbuf.width > COVER_MAXWIDTH
                new_height = pixbuf.height / 
                             (pixbuf.width / COVER_MAXWIDTH.to_f)
                # We don't want to modify in place the given pixbuf, 
                # that's why we make a copy.
                pixbuf = pixbuf.scale(COVER_MAXWIDTH, new_height)
            end
            @image_cover.pixbuf = pixbuf
        end

        def loaned_since=(time)
            @date_loaned_since.time = time
            # XXX 'date_changed' signal not automatically called after #time=.
            on_loaned_date_changed
        end
    end
end
end
