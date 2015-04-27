require 'rdoc/task'

RDoc::Task.new do |rdoc|
  rdoc.main = 'README.rdoc'
  rdoc.rdoc_files.include 'README.rdoc', 'INSTALL.rdoc', 'lib/**/*.rb'
end

