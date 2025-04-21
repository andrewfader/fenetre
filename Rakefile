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

# Add parallel test configuration
begin
  require 'parallel_tests/tasks'
  require_relative 'lib/fenetre/parallel_formatter'

  namespace :parallel do
    desc 'Setup parallel tests with 4 processors'
    task :setup do
      require 'fileutils'
      FileUtils.mkdir_p 'tmp/parallel_tests'
      4.times do |n|
        FileUtils.cp 'test/dummy/config/database.yml', "test/dummy/config/database.#{n}.yml"
      end
    end

    # Override the default parallel:test task to use our custom formatter
    desc 'Run tests in parallel with custom formatting'
    task :test do
      abort 'parallel_tests needs to be installed' unless system('bundle show parallel_tests', out: File::NULL)

      # Set formatter options for parallel_tests
      command_options = [
        "-n #{ENV['PARALLEL_TEST_PROCESSORS'] || Parallel.processor_count}",
        '--type test',
        "-o '--format Fenetre::TestFormatter'", # Custom Minitest formatter for individual tests
        '--serialize-stdout', # Prevent output from being mixed up
        '--combine-stderr'    # Combine stderr with stdout
      ]

      # Get test directory
      test_folders = FileList['test/**/*_test.rb'].map { |f| File.dirname(f) }.uniq

      # Execute parallel_tests with our custom formatter
      command = "bundle exec parallel_test #{test_folders.join(' ')} #{command_options.join(' ')} --format Fenetre::ParallelFormatter"
      puts "Running: #{command}"
      system(command) or exit(1)
    end
  end
rescue LoadError
  puts "parallel_tests gem not found. Run 'bundle install' first."
end

# Run tests with coverage by default
task default: %i[parallel:test]
