# frozen_string_literal: true

require 'application_system_test_case'

module Fenetre
  class BareSpecifierSystemTest < ApplicationSystemTestCase
    test 'no bare specifier errors for critical dependencies' do
      # Track specific bare specifier errors we're looking for
      setup_specific_bare_specifier_tracking

      # Visit a page that loads the Fenetre JavaScript
      visit '/video_chat?room_id=testroom&user_id=123'

      # Wait for the page to fully load
      assert_selector '[data-controller="fenetre--video-chat"]', wait: 5
      sleep 0.5

      # Check for bare specifier errors (safer approach)
      all_errors = page.evaluate_script(<<~JS)
        {
          bareSpecifierErrors: window.bareSpecifierErrors || [],
          consoleErrors: window.consoleErrors || [],
          importMapData: (function() {
            const importMapTag = document.querySelector('script[type="importmap"]');
            if (!importMapTag) return { imports: {} };
            try {
              // Ensure textContent is not empty before parsing
              const content = importMapTag.textContent || '{}';
              return JSON.parse(content);
            } catch (e) {
              console.error("Failed to parse import map:", e, importMapTag.textContent); // Add logging
              return { imports: {} };
            }
          })(),
          scriptSources: Array.from(document.querySelectorAll('script[type="module"]')).map(s => s.textContent)
        }
      JS

      bare_errors = all_errors['bareSpecifierErrors']
      console_errors = all_errors['consoleErrors']
      import_map_data = all_errors['importMapData']
      script_sources = all_errors['scriptSources']

      puts "Bare specifier errors: #{bare_errors.inspect}"
      puts "Console errors: #{console_errors.inspect}"
      puts "Import map: #{import_map_data.inspect}"
      puts "Script sources: #{script_sources.inspect}"

      # Check for application and stimulus bare specifier errors
      application_errors = bare_errors.select do |error|
        error.to_s.include?('application') && error.to_s.include?('bare specifier')
      end
      stimulus_errors = bare_errors.select do |error|
        error.to_s.include?('@hotwired/stimulus') && error.to_s.include?('bare specifier')
      end

      # Also check console errors as they might contain bare specifier messages
      console_application_errors = console_errors.select do |error|
        error.to_s.include?('application') && error.to_s.include?('bare specifier')
      end
      console_stimulus_errors = console_errors.select do |error|
        error.to_s.include?('@hotwired/stimulus') && error.to_s.include?('bare specifier')
      end

      # Combine both types of errors
      all_application_errors = application_errors + console_application_errors
      all_stimulus_errors = stimulus_errors + console_stimulus_errors

      # Assert no errors for each dependency
      assert_empty all_application_errors,
                   "Found bare specifier errors for 'application': #{all_application_errors.inspect}"

      assert_empty all_stimulus_errors,
                   "Found bare specifier errors for '@hotwired/stimulus': #{all_stimulus_errors.inspect}"

      # Verify import map contains either 'application' or 'dummy_app' mapping
      mappings = import_map_data['imports'] || {}

      # In the dummy app, 'application' is mapped as 'dummy_app'
      assert(mappings.key?('application') || mappings.key?('dummy_app'),
             "Import map missing application mapping. Current mappings: #{mappings.keys.join(', ')}")

      assert mappings.key?('@hotwired/stimulus'),
             "Import map missing '@hotwired/stimulus' mapping. Current mappings: #{mappings.keys.join(', ')}"
    end

    private

    def setup_specific_bare_specifier_tracking
      page.execute_script(<<~JS)
        // Initialize error tracking arrays
        window.bareSpecifierErrors = [];
        window.consoleErrors = [];

        // Track JavaScript errors, specifically bare specifier errors
        window.addEventListener('error', function(event) {
          const errorMessage = event.message || (event.error && event.error.toString()) || '';
        #{'  '}
          // Capture all errors for debugging
          if (errorMessage.includes('bare specifier')) {
            window.bareSpecifierErrors.push(errorMessage);
          }
        });

        // Also track console errors which might include module loading issues
        const originalConsoleError = console.error;
        console.error = function() {
          const args = Array.from(arguments);
          window.consoleErrors.push(args.map(arg => arg && arg.toString ? arg.toString() : String(arg)).join(' '));
          originalConsoleError.apply(console, args);
        };

        // Track unhandled promise rejections which might contain module errors
        window.addEventListener('unhandledrejection', function(event) {
          const errorMessage = event.reason && event.reason.toString ? event.reason.toString() : '';
        #{'  '}
          if (errorMessage.includes('bare specifier')) {
            window.bareSpecifierErrors.push(errorMessage);
          }
        });
      JS
    end
  end
end
