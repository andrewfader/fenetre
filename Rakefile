# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rubocop/rake_task'

Rake::TestTask.new(:test) do |task|
  task.libs += %w[test lib]
  task.test_files = FileList['test/**/*_test.rb']
end

Rake::TestTask.new('test:javascript') do |task|
  task.libs += %w[test lib]
  task.test_files = FileList['test/system/javascript_test.rb']
end

RuboCop::RakeTask.new(:rubocop)

desc 'Run the suite with coverage'
task :coverage do
  ENV['COVERAGE'] = 'true'
  Rake::Task[:test].invoke
end

namespace :parallel do
  desc 'Run the test suite in separate processes'
  task :test do
    sh 'bundle', 'exec', 'parallel_test', 'test', '--type', 'test',
       '-n', ENV.fetch('PARALLEL_TEST_PROCESSORS', '2'), '--serialize-stdout', '--combine-stderr'
  end
end

task default: %i[test rubocop]
