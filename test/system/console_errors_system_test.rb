# frozen_string_literal: true

require 'application_system_test_case'

class ConsoleErrorsSystemTest < ApplicationSystemTestCase
  setup do
    # Initialize Capybara session management
    Capybara.reset_sessions!

    # Set up more comprehensive error tracking in JavaScript
    page.execute_script(<<-JS)
      // Array to collect all types of errors
      window.jsErrors = [];
      window.jsWarnings = [];
      window.jsExceptions = [];
      window.jsNetworkErrors = [];

      // Save original console methods
      const originalConsoleError = console.error;
      const originalConsoleWarn = console.warn;

      // Override console.error
      console.error = function() {
        window.jsErrors.push(Array.from(arguments).join(' '));
        originalConsoleError.apply(console, arguments);
      };

      // Override console.warn
      console.warn = function() {
        window.jsWarnings.push(Array.from(arguments).join(' '));
        originalConsoleWarn.apply(console, arguments);
      };

      // Catch uncaught exceptions
      window.addEventListener('error', function(event) {
        window.jsExceptions.push({
          message: event.message,#{' '}
          source: event.filename,
          lineno: event.lineno
        });
      });

      // Catch network errors
      window.addEventListener('unhandledrejection', function(event) {
        if (event.reason && typeof event.reason === 'object') {
          window.jsNetworkErrors.push(event.reason.message || 'Promise rejection');
        } else {
          window.jsNetworkErrors.push('Promise rejection: ' + event.reason);
        }
      });
    JS
  end

  def collect_all_errors
    {
      errors: page.evaluate_script('window.jsErrors') || [],
      warnings: page.evaluate_script('window.jsWarnings') || [],
      exceptions: page.evaluate_script('window.jsExceptions') || [],
      network_errors: page.evaluate_script('window.jsNetworkErrors') || []
    }
  end

  def assert_no_javascript_issues(error_data)
    # Check for console errors
    assert_empty error_data[:errors], "JavaScript console.error found: #{error_data[:errors].join(', ')}"

    # Check for uncaught exceptions
    assert_empty error_data[:exceptions], "JavaScript exceptions found: #{error_data[:exceptions].inspect}"

    # Check for network errors
    assert_empty error_data[:network_errors],
                 "JavaScript network errors found: #{error_data[:network_errors].join(', ')}"

    # Warnings are reported but don't cause the test to fail
    return if error_data[:warnings].empty?

    puts "WARNING: JavaScript console.warn messages detected: #{error_data[:warnings].join(', ')}"
  end

  test 'no JavaScript console errors when loading video chat' do
    visit '/video_chat?room_id=testroom&user_id=1'

    # Wait for the page to fully load and scripts to initialize
    assert_selector '[data-controller="fenetre--video-chat"]', wait: 5

    # Give time for any potential errors to be logged
    sleep 3

    # Collect and assert on JavaScript errors
    error_data = collect_all_errors
    assert_no_javascript_issues(error_data)
  end

  test 'no JavaScript console errors when interacting with video controls' do
    visit '/video_chat?room_id=testroom&user_id=2'

    # Wait for page to load
    assert_selector '[data-controller="fenetre--video-chat"]'

    # Interact with video toggle button
    find('button[data-action*="fenetre--video-chat#toggleVideo"]').click
    sleep 1

    # Interact with audio toggle button
    find('button[data-action*="fenetre--video-chat#toggleAudio"]').click
    sleep 1

    # Collect and assert on JavaScript errors
    error_data = collect_all_errors
    assert_no_javascript_issues(error_data)
  end

  test 'no JavaScript console errors when sending chat messages' do
    visit '/video_chat?room_id=testroom&user_id=3'

    # Wait for page to load
    assert_selector '[data-controller="fenetre--video-chat"]'

    # Type and send a chat message
    find('input[data-fenetre-video-chat-target="chatInput"]').fill_in with: 'Test message'
    find('button[data-action*="fenetre--video-chat#sendChat"]').click
    sleep 1

    # Collect and assert on JavaScript errors
    error_data = collect_all_errors
    assert_no_javascript_issues(error_data)
  end
end
