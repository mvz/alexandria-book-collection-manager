# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

module Alexandria
  module UI
    class BuilderBase
      def initialize(filename, widget_names)
        file = File.join(Alexandria::Config::DATA_DIR, "glade", filename)
        builder = Gtk::Builder.new
        # TODO: This emits the warning 'GtkDialog mapped without a transient
        # parent. This is discouraged.'
        builder.add_from_file(file)
        builder.connect_signals do |handler_name|
          method(handler_name)
        end

        widget_names.each do |name|
          instance_variable_set("@#{name}".intern, builder.get_object(name.to_s))
        end
      end
    end
  end
end
