# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
end

# Add RuboCop task
begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new(:rubocop) do |task|
    task.options = ['--display-cop-names']
  end
rescue LoadError
  desc 'Run RuboCop'
  task :rubocop do
    abort 'RuboCop is not available. Run `bundle install` to install it.'
  end
end

# Add Coverage task
desc 'Generate test coverage report'
task :coverage do
  ENV['COVERAGE'] = 'true'
  Rake::Task['test'].invoke
end

# Run tests with coverage by default
task default: %i[rubocop coverage]
