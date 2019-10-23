# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

module Alexandria
  module EntryOverrides
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
      # min = self.completion.minimum_key_length
      min = 2
      completion.signal_connect("match-selected") do |c, model, iter|
        cur_text = c.entry.text
        # TODO: Replace with iter[0] if possible
        new_tag = model.get_value(iter, 0)
        cur_text_split = cur_text.split(",")
        cur_text_split.delete_at(-1)
        cur_text_split << new_tag
        c.entry.text = cur_text_split.join(",")
        true
      end
      completion.set_match_func do |_comp, key, iter|
        cur_tag = key.split(",").last.strip
        if cur_tag.size >= min
          begin
            if /^#{cur_tag}/.match?(iter[0])
              true
            else
              false
            end
          rescue StandardError
            false
          end
        else
          false
        end
      end
    end

    private

    def complete(model_id)
      completion = Gtk::EntryCompletion.new
      model = Alexandria::UI::CompletionModels.instance.models[model_id]
      completion.model = model
      completion.text_column = 0
      self.completion = completion
    end
  end
end

Gtk::Entry.prepend Alexandria::EntryOverrides

module Alexandria
  module UI
    class CompletionModels
      include Singleton

      TITLE, AUTHOR, PUBLISHER, EDITION, BORROWER, TAG = (0..6).to_a

      def initialize
        @models = []
        @libraries = []
        5.times { @models << Gtk::ListStore.new(String) }
        @models << Gtk::ListStore.new(String)
        touch
      end

      def add_source(library)
        @libraries << library
        library.add_observer(self)
        touch
      end

      def remove_source(library)
        @libraries.delete_if { |x| x.name == library.name }
        library.delete_observer(self)
        touch
      end

      def update(_library, _kind, _book)
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

      private

      def touch
        @dirty = true
      end

      def dirty?
        @dirty
      end

      def rebuild_models
        titles = []
        authors = []
        publishers = []
        editions = []
        borrowers = []
        tags = []
        @libraries.each do |library|
          library.each do |book|
            titles << book.title
            authors.concat(book.authors)
            publishers << book.publisher
            editions << book.edition
            borrowers << book.loaned_to
            # TODO: Ensure #tags is always an array
            (book.tags || []).each { |tag| tags << tag }
          end
        end

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
