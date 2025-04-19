# frozen_string_literal: true

require 'rake'
require 'rake/tasklib'

namespace :test do
  # Task to run QUnit JavaScript tests using Capybara
  desc 'Run JavaScript tests using QUnit and Capybara'
  task javascript: :environment do
    puts "\nRunning JavaScript tests..."

    require 'capybara/dsl'
    require 'capybara/minitest'
    require_relative '../../test/application_system_test_case' # Load system test config

    # Use the same driver as system tests
    Capybara.current_driver = Capybara.javascript_driver
    Capybara.app_host = "http://#{Capybara.server_host}:#{Capybara.server_port}"

    include Capybara::DSL

    # Visit the QUnit runner page
    visit '/javascript_tests'

    # Wait for QUnit to finish and results to be available
    # Wait for the #qunit-testresult element which QUnit populates when done.
    # Increase wait time if tests are slow to load/run.
    results_element = find('#qunit-testresult', wait: 30)

    # Extract results using JavaScript evaluation
    total = evaluate_script("document.querySelector('#qunit-testresult .total').textContent")
    passed = evaluate_script("document.querySelector('#qunit-testresult .passed').textContent")
    failed = evaluate_script("document.querySelector('#qunit-testresult .failed').textContent")

    puts "QUnit Results: #{total} tests, #{passed} passed, #{failed} failed."

    # Report failures if any
    if failed.to_i > 0
      puts "\nJavaScript Test Failures:"
      # Find all failed test list items
      failed_tests = all('#qunit-tests > li.fail')
      failed_tests.each do |test_li|
        # Extract module name and test name
        module_name = test_li.find('span.module-name', visible: :all)&.text
        test_name = test_li.find('span.test-name', visible: :all)&.text
        puts "- #{module_name} :: #{test_name}"

        # Extract assertion failure details
        assertion_message = test_li.find('span.test-message', visible: :all)&.text
        puts "  Message: #{assertion_message}" if assertion_message

        # Extract diff if present (optional, might need refinement)
        diff = test_li.find('table.diff', visible: :all)&.text
        puts "  Diff:\n#{diff}" if diff
      end
      # Fail the Rake task
      raise 'JavaScript tests failed!'
    else
      puts 'JavaScript tests passed.'
    end
  ensure
    Capybara.reset_sessions!
    Capybara.use_default_driver
  end
end

# Enhance the default test task to include javascript tests
# Ensure this runs after the default :test task might be defined elsewhere
Rake::Task[:test].enhance(['test:javascript'])
