# frozen_string_literal: true

require 'rake'
require 'rake/tasklib'

namespace :test do
  # Task to run QUnit JavaScript tests using Capybara
  desc 'Run JavaScript tests using QUnit and Capybara'
  task javascript: :environment do
    include Fenetre::TestFormatter::COLORS # Import color constants

    puts "\n[34m=== Running JavaScript Tests ===[0m"

    require 'capybara/dsl'
    require 'capybara/minitest'
    require_relative '../../test/application_system_test_case' # Load system test config

    # Use the same driver as system tests
    Capybara.current_driver = Capybara.javascript_driver
    Capybara.app_host = "http://#{Capybara.server_host}:#{Capybara.server_port}"

    include Capybara::DSL

    puts "\e[36mVisiting JavaScript test runner page...\e[0m"

    # Visit the QUnit runner page
    visit '/javascript_tests'

    # Wait for QUnit to finish and results to be available
    # Wait for the #qunit-testresult element which QUnit populates when done.
    # Increase wait time if tests are slow to load/run.
    puts "\e[36mWaiting for tests to complete...\e[0m"
    find('#qunit-testresult', wait: 30)

    # Extract results using JavaScript evaluation
    total = evaluate_script("document.querySelector('#qunit-testresult .total').textContent")
    passed = evaluate_script("document.querySelector('#qunit-testresult .passed').textContent")
    failed = evaluate_script("document.querySelector('#qunit-testresult .failed').textContent")

    # Get detailed test results for better reporting
    test_results = evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('#qunit-tests > li')).map(item => {
        const moduleElem = item.querySelector('.module-name');
        const testElem = item.querySelector('.test-name');
        const passedElem = item.querySelector('.counts .passed');
        const failedElem = item.querySelector('.counts .failed');
        const totalElem = item.querySelector('.counts .total');
      #{'  '}
        // Get all assertion messages
        const assertions = Array.from(item.querySelectorAll('.qunit-assert-list li')).map(assertItem => {
          const message = assertItem.querySelector('.test-message')?.textContent || '';
          const result = assertItem.classList.contains('pass') ? 'pass' : 'fail';
          const source = assertItem.querySelector('.source')?.textContent || '';
      #{'    '}
          return {
            message,
            result,
            source
          };
        });
      #{'  '}
        return {
          module: moduleElem ? moduleElem.textContent : '',
          test: testElem ? testElem.textContent : '',
          passed: passedElem ? parseInt(passedElem.textContent, 10) : 0,
          failed: failedElem ? parseInt(failedElem.textContent, 10) : 0,
          total: totalElem ? parseInt(totalElem.textContent, 10) : 0,
          result: item.classList.contains('pass') ? 'pass' : 'fail',
          assertions
        };
      });
    JS

    # Format the results in a visually appealing way
    puts "\n[34m=== Test Results ===[0m"
    puts "[36mQUnit Results: #{total} tests, [32m#{passed} passed[0m, #{failed.to_i.positive? ? "\e[31m" : "\e[32m"}#{failed} failed[0m."

    if failed.to_i.positive?
      puts "\n[31mJavaScript Test Failures:[0m"

      # Group tests by module for better organization
      test_results_by_module = test_results.group_by { |test| test['module'] }

      test_results_by_module.each do |module_name, tests|
        failed_tests = tests.select { |test| test['result'] == 'fail' }
        next if failed_tests.empty?

        puts "\n[35mModule: #{module_name}[0m"

        failed_tests.each do |test|
          puts "  [31m✗[0m [1m#{test['test']}[0m (#{test['passed']}/#{test['total']} assertions passed)"

          # Show failed assertions with details
          test['assertions'].each_with_index do |assertion, idx|
            next if assertion['result'] == 'pass'

            puts "    [33m#{idx + 1})[0m [31mAssertion Failed:[0m #{assertion['message']}"

            next unless assertion['source'] && !assertion['source'].empty?

            # Format the source code for better readability
            source_lines = assertion['source'].split("\n").map(&:strip)
            puts "       \e[36mSource:\e[0m"
            source_lines.each do |line|
              puts "         #{line}"
            end
          end
        end
      end

      # Fail the Rake task
      raise "\e[31mJavaScript tests failed!\e[0m"
    else
      puts "\e[32mAll JavaScript tests passed! 🎉\e[0m"
    end
  ensure
    Capybara.reset_sessions!
    Capybara.use_default_driver
  end
end

# Enhance the default test task to include javascript tests
# Ensure this runs after the default :test task might be defined elsewhere
Rake::Task[:test].enhance(['test:javascript']) if Rake::Task.task_defined?(:test)
