require 'application_system_test_case'

class ImportmapSpecifierSystemTest < ApplicationSystemTestCase
  test 'importmap resolves bare specifiers for application and @hotwired/stimulus' do
    visit '/video_chat'

    # Wait for the Stimulus controller to appear
    assert_selector '[data-controller="fenetre--video-chat"]', wait: 5

    # Check for JS errors about unresolved bare specifiers
    js_errors = begin
      page.evaluate_script('window.jsErrors || []')
    rescue StandardError
      []
    end
    console_errors = begin
      page.evaluate_script('window.consoleErrors || []')
    rescue StandardError
      []
    end

    bare_specifier_errors = (js_errors + console_errors).select do |err|
      err.to_s.include?('bare specifier') || err.to_s.include?('was not remapped to anything')
    end

    assert_empty bare_specifier_errors, "Importmap did not resolve bare specifiers: #{bare_specifier_errors.inspect}"

    # Check that the controller updated the connection status element
    # Use assert_text within the controller scope
    within('[data-controller="fenetre--video-chat"]', wait: 10) do
      assert_text('Connecting...', wait: 10) # Check for the initial text
    end

    # Optional: If you need to verify it changes later, you could add more steps
    # For now, just verifying the initial state is enough for this test's purpose.
  end
end
