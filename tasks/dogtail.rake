desc 'run dogtail integration tests'
task :dogtail do
  `RUBYOPT=-Ilib python dogtail/*.py` 
end
