desc 'run dogtail integration tests'
task :dogtail do
  `RUBYOPT='-rbundler/setup -Ilib' python dogtail/*.py`
end
