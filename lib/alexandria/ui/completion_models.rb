# Copyright (C) 2005 Laurent Sansonetti
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

class Gtk::Entry
    def complete_titles
        complete(Alexandria::UI::CompletionModels::TITLE)
    end

    def complete_authors
        complete(Alexandria::UI::CompletionModels::AUTHOR)
    end

    def complete_publishers
        complete(Alexandria::UI::CompletionModels::PUBLISHER)
    end

    def complete_editions
        complete(Alexandria::UI::CompletionModels::EDITION)
    end

    #######
    private
    #######

    def complete(model_id)
        completion = Gtk::EntryCompletion.new
        model = Alexandria::UI::CompletionModels.instance.models[model_id]
        completion.model = model
        completion.text_column = 0
        self.completion = completion 
    end
end

module Alexandria
module UI
    class CompletionModels
        include Singleton

        TITLE, AUTHOR, PUBLISHER, EDITION = (0..4).to_a

        def initialize
            @models = []
            4.times { @models << Gtk::ListStore.new(String) }
            touch
        end

        def libraries=(libraries)
            @libraries = libraries
            touch
        end

        def touch
            @dirty = true
        end

        def models
            rebuild_models if @dirty
            @models
        end
 
        def title_model
            rebuild_models if @dirty
            @models[TITLE]
        end

        def author_model
            rebuild_models if @dirty
            @models[AUTHOR]
        end

        def publisher_model
            rebuild_models if @dirty
            @models[PUBLISHER]
        end
        
        def edition_model
            rebuild_models if @dirty
            @models[EDITION]
        end

        #######
        private
        #######

        def rebuild_models
            titles, authors, publishers, editions = [], [], [], []
            @libraries.each do |library|
                library.each do |book|
                    titles << book.title
                    authors.concat(book.authors)
                    publishers << book.publisher
                    editions << book.edition
                end
            end
            fill_model(@models[TITLE], titles)
            fill_model(@models[AUTHOR], authors)
            fill_model(@models[EDITION], editions)
            fill_model(@models[PUBLISHER], publishers)
            @dirty = false
        end

        def fill_model(model, values)
            model.clear
            iter = nil
            values.uniq.each do |value|
                iter = iter ? model.insert_after(iter) : model.append 
                iter[0] = value
            end
        end
    end
end
end
