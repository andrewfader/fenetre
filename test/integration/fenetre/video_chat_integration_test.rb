require 'test_helper'

module Fenetre
  class VideoChatIntegrationTest < ActionDispatch::IntegrationTest
    test "video chat page loads with all required elements" do
      get "/video_chat?room_id=testroom&user_id=1"
      assert_response :success
      
      # Verify that the page contains the video chat controller
      assert_select '[data-controller="fenetre--video-chat"]'
      
      # Verify that the page has video elements
      assert_select 'video[data-fenetre-video-chat-target="localVideo"]'
      assert_select 'div[data-fenetre-video-chat-target="remoteVideos"]'
      
      # Verify that the room ID is set correctly
      assert_select 'input[data-fenetre-video-chat-target="roomId"][value=?]', 'testroom', visible: false
      
      # Verify that the user ID is set correctly
      assert_select 'input[data-fenetre-video-chat-target="userId"][value=?]', '1', visible: false
      
      # Check if chat UI elements are present
      assert_select 'div[data-fenetre-video-chat-target="chatMessages"]'
      assert_select 'input[data-fenetre-video-chat-target="chatInput"]'
      
      # Check if media control buttons are present
      assert_select 'button[data-action*="fenetre--video-chat#toggleVideo"]'
      assert_select 'button[data-action*="fenetre--video-chat#toggleAudio"]'
    end
    
    test "video chat page loads with custom configuration" do
      get "/video_chat?room_id=configtest&user_id=2&room_topic=Test%20Meeting&max_participants=5"
      assert_response :success
      
      # Verify the base controller is present
      assert_select '[data-controller="fenetre--video-chat"]'
      
      # Verify room topic is displayed
      assert_select 'h1, h2, h3, h4, h5, h6, span', text: /Test Meeting/
      
      # Verify configuration parameters are set
      assert_select 'input[data-fenetre-video-chat-target="maxParticipants"][value=?]', '5', visible: false
    end
    
    test "video chat javascript controller is properly loaded" do
      get "/video_chat?room_id=jstest&user_id=3"
      assert_response :success
      
      # Check that the Stimulus controller JavaScript is included
      assert_match(/fenetre--video-chat/, response.body)
      
      # Check that the controller registration appears somewhere in the page
      assert_match(/data-controller="fenetre--video-chat"/, response.body)
    end
  end
end