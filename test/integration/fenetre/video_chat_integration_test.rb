# frozen_string_literal: true

require 'test_helper'

module Fenetre
  class VideoChatIntegrationTest < ActionDispatch::IntegrationTest
    test 'video chat page loads with all required elements' do
      visit '/video_chat?room_id=testroom&user_id=1'
      assert_selector 'div[data-controller="fenetre--video-chat"]'
      assert_selector 'video[data-fenetre-video-chat-target="localVideo"]'
      assert_selector 'div[data-fenetre-video-chat-target="remoteVideos"]'
      assert_selector 'input[value="testroom"]', visible: :all
      assert_text 'Room ID: testroom'
    end

    test 'video chat page loads with custom configuration' do
      visit '/video_chat?room_id=configtest&user_id=2&room_topic=Test%20Meeting&max_participants=5'
      assert_selector 'div[data-controller="fenetre--video-chat"]'
      assert_text 'Room ID: configtest'
    end

    test 'video chat javascript controller is properly loaded' do
      visit '/video_chat?room_id=jstest&user_id=3'
      assert_selector 'div[data-controller="fenetre--video-chat"]'
    end
  end
end
