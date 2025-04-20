# frozen_string_literal: true

require 'application_system_test_case'

module Fenetre
  class BareSpecifierSystemTest < ApplicationSystemTestCase
    setup do
      # Initialize Capybara session management
      Capybara.reset_sessions!

      # Set up error tracking in JavaScript
      page.execute_script(<<-JS)
        // Arrays to collect errors
        window.jsErrors = [];
        window.jsExceptions = [];
        
        // Save original console method
        const originalConsoleError = console.error;

        // Override console.error
        console.error = function() {
          window.jsErrors.push(Array.from(arguments).join(' '));
          originalConsoleError.apply(console, arguments);
        };

        // Catch uncaught exceptions
        window.addEventListener('error', function(event) {
          window.jsExceptions.push({
            message: event.message,
            source: event.filename,
            lineno: event.lineno
          });
        });
      JS
    end

    def collect_errors
      {
        errors: page.evaluate_script('window.jsErrors') || [],
        exceptions: page.evaluate_script('window.jsExceptions') || []
      }
    end

    test 'no bare specifier errors when loading JavaScript modules' do
      # Visit a page that loads the JavaScript modules
      visit '/video_chat?room_id=testroom&user_id=123'

      # Wait for the page to fully load and scripts to initialize
      assert_selector '[data-controller="fenetre--video-chat"]', wait: 5

      # Give time for any potential errors to be logged
      sleep 2

      # Collect JavaScript errors
      error_data = collect_errors
      
      # Check specifically for bare specifier errors
      bare_specifier_errors = error_data[:errors].select { |error| error.include?('bare specifier') }
      assert_empty bare_specifier_errors, 
                   "Found bare specifier errors: #{bare_specifier_errors.join(', ')}"
      
      # Also make sure we don't have exceptions that might be related to module loading
      module_exceptions = error_data[:exceptions].select do |ex| 
        ex[:message]&.include?('import') || ex[:message]&.include?('module')
      end
      assert_empty module_exceptions,
                   "Found module loading exceptions: #{module_exceptions.inspect}"
      
      # Check for other JS errors that might be module-related
      js_errors_regexp = /modules?|import|export|require/i
      module_errors = error_data[:errors].select { |error| error =~ js_errors_regexp }
      assert_empty module_errors,
                   "Found module-related errors: #{module_errors.join(', ')}"
    end
  end
end