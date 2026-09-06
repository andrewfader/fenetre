# frozen_string_literal: true

require_relative 'test_helper'

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium_chrome_headless

  def wait_for_script(script)
    Selenium::WebDriver::Wait.new(timeout: 15).until { page.evaluate_script(script) }
  end

  def controller_script
    %q(window.Stimulus.getControllerForElementAndIdentifier(document.querySelector('[data-controller="fenetre--video-chat"]'), "fenetre--video-chat"))
  end

  def visit_room(room)
    visit "/video_chat?room_id=#{room}"
    assert_selector '.fenetre-status-connected', text: 'Connected'
  end
end
