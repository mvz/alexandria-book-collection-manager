module Alexandria
module UI
    module Icons
        def self.init
            icons_dir = File.join(Alexandria::Config::DATA_DIR, "icons")
            Dir.entries(icons_dir).each do |file|
                next unless file =~ /\.png$/    # skip non '.png' files
                name = File.basename(file, ".png").upcase
                const_set(name, Gdk::Pixbuf.new(File.join(icons_dir, file)))
            end
        end
    end
end
end
