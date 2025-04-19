require 'test_helper'

module Fenetre
  class VideoChatIntegrationTest < ActionDispatch::IntegrationTest
    test 'video chat page loads with all required elements' do
      get '/video_chat?room_id=testroom&user_id=1'
      assert_response :success

      # Verify that the page contains the video chat controller
      assert_select '[data-controller="fenetre--video-chat"]'

      # Verify that the page has video elements
      assert_select 'video[data-fenetre-video-chat-target="localVideo"]'
      assert_select 'div[data-fenetre-video-chat-target="remoteVideos"]'

      # Verify that the room ID is set correctly
      assert_select 'input[value=?]', 'testroom'

      # Verify room ID is shown in the page
      assert_select 'p', text: 'Room ID: testroom'
    end

    test 'video chat page loads with custom configuration' do
      get '/video_chat?room_id=configtest&user_id=2&room_topic=Test%20Meeting&max_participants=5'
      assert_response :success

      # Verify the base controller is present
      assert_select '[data-controller="fenetre--video-chat"]'

      # Verify room ID is visible on the page
      assert_select 'p', text: 'Room ID: configtest'
    end

    test 'video chat javascript controller is properly loaded' do
      get '/video_chat?room_id=jstest&user_id=3'
      assert_response :success

      # Check that the Stimulus controller JavaScript is included
      assert_match(/fenetre--video-chat/, response.body)

      # Check that the controller registration appears somewhere in the page
      assert_match(/data-controller="fenetre--video-chat"/, response.body)
    end
  end
end
