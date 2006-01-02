# Copyright (C) 2005-1006 Laurent Sansonetti

unless system("which scrollkeeper-update")
    $stderr.puts "scrollkeeper-update cannot be found, is Scrollkeeper correctly " +
                 "installed?"
    exit 1
end

system('scrollkeeper-update -q alexandria-C.omf') or exit 1
