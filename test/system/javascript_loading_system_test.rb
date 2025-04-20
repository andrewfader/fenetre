# frozen_string_literal: true

require 'application_system_test_case'

module Fenetre
  class JavascriptLoadingSystemTest < ApplicationSystemTestCase
    test 'no JavaScript loading errors or 404s for required assets' do
      # Initialize JS error tracking
      setup_js_error_tracking

      # Visit a page that loads the Fenetre JavaScript
      visit '/video_chat?room_id=testroom&user_id=123'

      # Wait for the page to fully load
      assert_selector '[data-controller="fenetre--video-chat"]', wait: 5

      # Give time for any potential errors to be logged
      sleep 2

      # Collect errors
      errors = collect_js_errors

      # Check for specific 404 errors we want to prevent
      assert_no_404_errors([
                             '/javascript/controllers/fenetre/video_chat_controller.js',
                             '/assets/fenetre/vendor/stimulus.min.js'
                           ])

      # Check for bare specifier errors
      bare_specifier_errors = errors[:errors].select { |e| e.include?('bare specifier') }

      assert_empty bare_specifier_errors,
                   "Found bare specifier errors: #{bare_specifier_errors.join(', ')}"

      # Check for import map related errors
      importmap_errors = errors[:errors].select { |e| e.include?('Import maps') }

      assert_empty importmap_errors,
                   "Found import map errors: #{importmap_errors.join(', ')}"

      # Check for module loading failures
      module_errors = errors[:errors].select { |e| e.include?('Loading failed for the module') }

      assert_empty module_errors,
                   "Found module loading errors: #{module_errors.join(', ')}"
    end

    private

    def setup_js_error_tracking
      # Initialize error tracking arrays in the browser
      page.execute_script(<<~JS)
        window.jsErrors = [];
        window.jsExceptions = [];
        window.networkErrors = [];

        // Track console errors
        const originalConsoleError = console.error;
        console.error = function() {
          window.jsErrors.push(Array.from(arguments).join(' '));
          originalConsoleError.apply(console, arguments);
        };

        // Track uncaught exceptions
        window.addEventListener('error', function(event) {
          window.jsExceptions.push({
            message: event.message,
            source: event.filename,
            lineno: event.lineno
          });
        });

        // Track network errors
        const originalFetch = window.fetch;
        window.fetch = function(url, options) {
          return originalFetch(url, options)
            .then(response => {
              if (!response.ok) {
                window.networkErrors.push({
                  url: url.toString(),
                  status: response.status,
                  statusText: response.statusText
                });
              }
              return response;
            })
            .catch(error => {
              window.networkErrors.push({
                url: url.toString(),
                error: error.toString()
              });
              throw error;
            });
        };
      JS
    end

    def collect_js_errors
      {
        errors: page.evaluate_script('window.jsErrors || []'),
        exceptions: page.evaluate_script('window.jsExceptions || []'),
        network_errors: page.evaluate_script('window.networkErrors || []')
      }
    end

    def assert_no_404_errors(paths)
      # Get network errors from the performance API
      network_data = page.evaluate_script(<<~JS)
        performance.getEntriesByType('resource')
          .filter(resource => resource.responseStatus === 404)
          .map(resource => ({#{' '}
            url: resource.name,#{' '}
            status: resource.responseStatus#{' '}
          }))
      JS

      # Check if any of the paths have 404 errors
      paths.each do |path|
        matching_errors = network_data.select { |entry| entry['url'].include?(path) }

        assert_empty matching_errors, "Found 404 errors for #{path}: #{matching_errors.inspect}"
      end
    end
  end
end
