# Copyright (C) 2005-2006 Laurent Sansonetti
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

  def complete_borrowers
    complete(Alexandria::UI::CompletionModels::BORROWER)
  end

  def complete_tags
    complete(Alexandria::UI::CompletionModels::TAG)
    #min = self.completion.minimum_key_length
    min = 2
    self.completion.signal_connect('match-selected') do |c, model, iter|
      cur_text = c.entry.text
      new_tag = model.get_value(iter, 0)
      cur_text_split = cur_text.split(",")
      cur_text_split.delete_at -1
      cur_text_split << new_tag
      c.entry.text = cur_text_split.join(",")      
      true
    end
    self.completion.set_match_func do |comp, key, iter|
      cur_tag = key.split(",").last.strip
      if cur_tag.size >= min
        begin
          if (iter[0] =~ /^#{cur_tag}/)
            true
          else
            false
          end
        rescue
          false
        end
      else
        false
      end
    end
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

begin
  require 'revolution'

  EVOLUTION_CONTACTS =
    Revolution::Revolution.new.get_all_contacts.map do |contact|
    first, last = contact.first_name, contact.last_name

    if first
      first.strip!
      first = nil if first.empty?
    end

    if last
      last.strip!
      last = nil if last.empty?
    end

    first and last ? first + ' ' + last : first ? first : last
  end
rescue LoadError => e
  Alexandria::log.debug { "Could not find optional ruby-revolution; Evolution contacts will not be loaded"}
  EVOLUTION_CONTACTS = []
rescue Exception => e
  Alexandria::log.warn { e.message }
  EVOLUTION_CONTACTS = []
end

module Alexandria
  module UI
    class CompletionModels
      include Singleton

      TITLE, AUTHOR, PUBLISHER, EDITION, BORROWER, TAG = (0..6).to_a

      def initialize
        @models, @libraries = [], []
        5.times { @models << Gtk::ListStore.new(String) }
        @models <<Gtk::ListStore.new(String)
        touch
      end

      def add_source(library)
        @libraries << library
        library.add_observer(self)
        touch
      end

      def remove_source(library)
        @libraries.delete_if { |x| x.name == library.name}
        library.delete_observer(self)
        touch
      end

      def update(library, kind, book)
        # FIXME: Do not rebuild all the models there.
        touch
      end

      def models
        rebuild_models if dirty?
        @models
      end

      def title_model
        rebuild_models if dirty?
        @models[TITLE]
      end

      def author_model
        rebuild_models if dirty?
        @models[AUTHOR]
      end

      def publisher_model
        rebuild_models if dirty?
        @models[PUBLISHER]
      end

      def edition_model
        rebuild_models if dirty?
        @models[EDITION]
      end

      def borrower_model
        rebuilds_models if dirty?
        @models[BORROWER]
      end

      def tag_model
        rebuilds_models if dirty?
        @models[TAG]
      end

      #######
      private
      #######

      def touch
        @dirty = true
      end

      def dirty?
        @dirty
      end

      def rebuild_models
        titles, authors, publishers, editions, borrowers = [],[],[],[],[]
        tags = []
        @libraries.each do |library|
          library.each do |book|
            titles << book.title
            authors.concat(book.authors)
            publishers << book.publisher
            editions << book.edition
            borrowers << book.loaned_to
            book.tags.each {|tag| tags << tag }
          end
        end

        borrowers.concat(EVOLUTION_CONTACTS)
        borrowers.uniq!

        tags.uniq!

        fill_model(@models[TITLE], titles)
        fill_model(@models[AUTHOR], authors)
        fill_model(@models[EDITION], editions)
        fill_model(@models[PUBLISHER], publishers)
        fill_model(@models[BORROWER], borrowers)
        fill_model(@models[TAG], tags)
        @dirty = false
      end

      def fill_model(model, values)
        model.clear
        iter = nil
        values.uniq.each do |value|
          next if value.nil?
          iter = iter ? model.insert_after(iter) : model.append
          iter[0] = value
        end
      end
    end
  end
end
