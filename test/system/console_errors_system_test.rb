# frozen_string_literal: true

require 'application_system_test_case'

class ConsoleErrorsSystemTest < ApplicationSystemTestCase
  test 'browser reports no script or network errors while connecting and using chat' do
    page.driver.browser.logs.get(:browser)
    visit_room('console-check')
    click_on 'Mute microphone'
    find('[data-fenetre--video-chat-target="chatInput"]').fill_in with: 'Console check'
    click_on 'Send'
    assert_selector '.fenetre-chat-message', text: 'Console check'
    errors = page.driver.browser.logs.get(:browser).select { |entry| entry.level == 'SEVERE' }
    assert_empty errors.map(&:message)
  end
end
