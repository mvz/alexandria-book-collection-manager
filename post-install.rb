# Copyright (C) 2004-2005 Laurent Sansonetti

# Install GConf2 .schemas files

exit 0 if ENV['GCONF_DISABLE_MAKEFILE_SCHEMA_INSTALL']

unless system("which gconftool-2")
    $stderr.puts "gconftool-2 cannot be found, is GConf2 correctly installed?"
    exit 1
end

ENV['GCONF_CONFIG_SOURCE'] = `gconftool-2 --get-default-source`.chomp
Dir["schemas/*.schemas"].each do |schema|
    system("gconftool-2 --makefile-install-rule '#{schema}'") 
end
