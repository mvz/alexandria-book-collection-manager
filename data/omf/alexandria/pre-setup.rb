# Copyright 2005 Laurent Sansonetti

path = File.join(config('data-dir'), 'gnome', 'help', 'alexandria', 'C', 'alexandria.xml')
data = IO.read('alexandria-C.omf.in')
data.sub!(/PATH_TO_DOC_FILE/, path)
File.open('alexandria-C.omf', 'w') { |io| io.puts data }


