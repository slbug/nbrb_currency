require 'bundler/gem_tasks'

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new
rescue LoadError
  task(:spec) { abort '`gem install rspec` to run specs' }
end

task default: :spec
task gem: :build
