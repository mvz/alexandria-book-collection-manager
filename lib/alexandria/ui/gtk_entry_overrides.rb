# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

module Alexandria
  module UI
    module GtkEntryOverrides
      def self.prepended(base)
        base.class_eval do
          attr_writer :mandatory
        end
      end

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
              /^#{cur_tag}/.match?(iter[0])
            rescue StandardError
              false
            end
          else
            false
          end
        end
      end

      def mandatory?
        @mandatory
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

    Gtk::Entry.prepend GtkEntryOverrides
  end
end
