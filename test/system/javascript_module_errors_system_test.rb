# frozen_string_literal: true

require 'application_system_test_case'

module Fenetre
  class JavascriptModuleErrorsSystemTest < ApplicationSystemTestCase
    test 'no JavaScript module loading errors in browser' do
      # Set up JavaScript error monitoring
      page.execute_script(<<~JS)
        window.jsErrors = [];
        window.consoleErrors = [];
        window.moduleErrors = [];
        window.networkErrors = [];

        // Track console errors
        const originalConsoleError = console.error;
        console.error = function() {
          const errorMsg = Array.from(arguments).join(' ');
          window.consoleErrors.push(errorMsg);
          originalConsoleError.apply(console, arguments);
        };

        // Track uncaught errors
        window.addEventListener('error', function(event) {
          window.jsErrors.push({
            message: event.message,
            source: event.filename,
            lineno: event.lineno
          });
        });

        // Specifically track module loading errors
        window.addEventListener('unhandledrejection', function(event) {
          if (event.reason && typeof event.reason.message === 'string') {
            if (event.reason.message.includes('module') ||#{' '}
                event.reason.message.includes('import') ||#{' '}
                event.reason.message.includes('bare specifier')) {
              window.moduleErrors.push(event.reason.message);
            }
          }
        });

        // Intercept network requests to track 404s
        const originalFetch = window.fetch;
        window.fetch = function(input, init) {
          return originalFetch(input, init)
            .then(response => {
              if (response.status === 404) {
                window.networkErrors.push({
                  url: typeof input === 'string' ? input : input.url,
                  status: 404
                });
              }
              return response;
            });
        };
      JS

      # Visit the page that loads our JavaScript
      visit '/video_chat'

      # Give time for scripts to load and errors to be captured
      sleep 3

      # Print all errors for debugging
      js_errors = page.evaluate_script('window.jsErrors || []')
      console_errors = page.evaluate_script('window.consoleErrors || []')
      module_errors = page.evaluate_script('window.moduleErrors || []')
      network_errors = page.evaluate_script('window.networkErrors || []')

      puts "JS Errors: #{js_errors.inspect}" unless js_errors.empty?
      puts "Console Errors: #{console_errors.inspect}" unless console_errors.empty?
      puts "Module Errors: #{module_errors.inspect}" unless module_errors.empty?
      puts "Network Errors: #{network_errors.inspect}" unless network_errors.empty?

      # Check for specific errors we want to test

      # 1. Check for "bare specifier" errors
      bare_specifier_errors = js_errors.select { |err| err['message'].to_s.include?('bare specifier') }
      module_bare_errors = module_errors.select { |err| err.include?('bare specifier') }
      console_bare_errors = console_errors.select { |err| err.include?('bare specifier') }

      assert_empty bare_specifier_errors + module_bare_errors + console_bare_errors,
                   "Found bare specifier errors: #{(bare_specifier_errors + module_bare_errors + console_bare_errors).inspect}"

      # 2. Check for "Import maps are not allowed" errors
      import_map_errors = console_errors.select { |err| err.include?('Import maps are not allowed') }

      assert_empty import_map_errors,
                   "Found import map errors: #{import_map_errors.inspect}"

      # 3. Check for missing JS files (404 errors)
      js_404_urls = [
        '/assets/fenetre/vendor/stimulus.min.js',
        '/javascript/controllers/fenetre/video_chat_controller.js'
      ]

      js_404_errors = js_404_urls.select do |url|
        network_errors.any? { |err| err[:url].to_s.include?(url) }
      end

      assert_empty js_404_errors,
                   "Found 404 errors for critical JavaScript files: #{js_404_errors.inspect}"

      # 4. Check for module loading failures
      loading_failed_errors = console_errors.select { |err| err.include?('Loading failed for the module') }

      assert_empty loading_failed_errors,
                   "Found module loading failures: #{loading_failed_errors.inspect}"
    end

    test 'specific bare specifiers for application and @hotwired/stimulus are properly mapped' do
      errors = []
      # Set up specialized JavaScript tracking for specific bare specifiers
      page.execute_script(<<~JS)
        window.specificBareSpecifierErrors = [];
        // Special handler for the specific bare specifiers we're targeting
        window.addEventListener('error', function(event) {
          const errorText = event.message || (event.error && event.error.toString()) || '';
          // Check for the specific bare specifier errors we're investigating
          if (errorText.includes('bare specifier') &&
              (errorText.includes('application') ||
               errorText.includes('@hotwired/stimulus'))) {
            window.specificBareSpecifierErrors.push({
              message: errorText,
              source: event.filename || 'unknown',
              specifier: errorText.includes('application') ? 'application' : '@hotwired/stimulus'
            });
          }
        });
        // Also track unhandled promise rejections which might contain module errors
        window.addEventListener('unhandledrejection', function(event) {
          const errorText = event.reason && event.reason.toString ? event.reason.toString() : '';
          if (errorText.includes('bare specifier') &&
              (errorText.includes('application') ||
               errorText.includes('@hotwired/stimulus'))) {
            window.specificBareSpecifierErrors.push({
              message: errorText,
              source: 'promise rejection',
              specifier: errorText.includes('application') ? 'application' : '@hotwired/stimulus'
            });
          }
        });
      JS

      # Visit the page and wait for it to load
      visit '/video_chat'

      # Wait for our video chat controller to appear
      assert_selector '[data-controller="fenetre--video-chat"]', wait: 5

      # Give time for JS to execute and errors to be captured
      sleep 3

      # Always define errors before using it
      errors = page.evaluate_script('window.specificBareSpecifierErrors || []')

      # Assert no errors for each specifier with descriptive messages
      assert_empty errors.select { |err| err['specifier'] == 'application' },
                   "Found 'application' bare specifier errors: #{errors.select { |err| err['specifier'] == 'application' }.inspect}"

      assert_empty errors.select { |err| err['specifier'] == '@hotwired/stimulus' },
                   "Found '@hotwired/stimulus' bare specifier errors: #{errors.select { |err| err['specifier'] == '@hotwired/stimulus' }.inspect}"

      # Verify import map mappings
      importmap_data = page.evaluate_script(<<~JS)
        (function() {
          const importMapTag = document.querySelector('script[type="importmap"]');
          if (!importMapTag) return { imports: {} };
          try {
            return JSON.parse(importMapTag.textContent);
          } catch (e) {
            return { imports: {} };
          }
        })()
      JS

      imports = importmap_data['imports'] || {}

      # Check if the import map has mappings for both specifiers
      assert imports.key?('@hotwired/stimulus'),
             "Import map missing '@hotwired/stimulus' mapping. Current mappings: #{imports.keys.join(', ')}"

      assert imports.key?('application'),
             "Import map missing 'application' mapping. Current mappings: #{imports.keys.join(', ')}"
    end
  end
end
