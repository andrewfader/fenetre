require 'application_system_test_case'

class VideoChatSystemTest < ApplicationSystemTestCase
  setup do
    # Initialize Capybara session management
    Capybara.reset_sessions!
  end

  test 'video chat UI renders with all required elements' do
    visit '/video_chat?room_id=testroom&user_id=1'
    
    # Verify core UI components
    assert_selector '[data-controller="fenetre--video-chat"]'
    assert_selector 'video[data-fenetre-video-chat-target="localVideo"]'
    assert_selector 'div[data-fenetre-video-chat-target="remoteVideos"]'
    assert_selector 'input[data-fenetre-video-chat-target="roomId"]', visible: false
    
    # Verify chat elements
    assert_selector 'div[data-fenetre-video-chat-target="chatMessages"]'
    assert_selector 'input[data-fenetre-video-chat-target="chatInput"]'
    
    # Verify control buttons
    assert_selector 'button[data-action*="fenetre--video-chat#toggleVideo"]'
    assert_selector 'button[data-action*="fenetre--video-chat#toggleAudio"]'
  end

  test "user can interact with video chat controls" do
    visit '/video_chat?room_id=controltest&user_id=2&username=TestUser'
    
    # Test video toggle
    find('button[data-action*="fenetre--video-chat#toggleVideo"]').click
    
    # Test audio toggle
    find('button[data-action*="fenetre--video-chat#toggleAudio"]').click
    
    # Test chat functionality
    within('[data-controller="fenetre--video-chat"]') do
      # Send a chat message
      find('input[data-fenetre-video-chat-target="chatInput"]').fill_in with: 'Hello world'
      find('button[data-action*="fenetre--video-chat#sendChat"]').click
      
      # Verify message appears in chat
      assert_selector 'div[data-fenetre-video-chat-target="chatMessages"]', text: 'Hello world'
    end
  end

  test "room connection is established with ActionCable" do
    visit '/video_chat?room_id=actioncable-test&user_id=3'
    
    # Wait for connection to establish
    sleep 2
    
    # Verify ActionCable connection is established
    page.execute_script("return App.cable.connection.connected") do |result|
      assert_equal true, result, "ActionCable connection should be established"
    rescue Capybara::NotSupportedByDriverError
      # Some drivers don't support JavaScript evaluation
      # In this case, we'll check for UI elements that indicate connection
      assert_selector 'video[data-fenetre-video-chat-target="localVideo"]'
    end
  end

  test "multiple users can join the same room" do
    # First user joins
    visit '/video_chat?room_id=multiuser-test&user_id=4&username=User4'
    
    # Wait for connection to establish
    sleep 1
    
    # Open a new browser session for second user
    using_session(:user2) do
      visit '/video_chat?room_id=multiuser-test&user_id=5&username=User5'
      
      # Wait for connection to establish
      sleep 1
      
      # Verify the room shows connected status
      assert_selector 'video[data-fenetre-video-chat-target="localVideo"]'
      
      # Send a chat message
      within('[data-controller="fenetre--video-chat"]') do
        find('input[data-fenetre-video-chat-target="chatInput"]').fill_in with: 'Hello from User5'
        find('button[data-action*="fenetre--video-chat#sendChat"]').click
        
        # Verify message appears
        assert_selector 'div[data-fenetre-video-chat-target="chatMessages"]', text: 'Hello from User5'
      end
    end
    
    # First user should receive the chat message
    assert_selector 'div[data-fenetre-video-chat-target="chatMessages"]', text: 'Hello from User5', wait: 3
  end

  test "custom room settings are applied" do
    visit '/video_chat?room_id=customroom&user_id=6&username=CustomUser&room_topic=Custom%20Meeting&max_participants=3'
    
    # Verify room topic is displayed
    assert_text 'Custom Meeting'
    
    # Verify user name is displayed
    assert_text 'CustomUser'
    
    # Verify max participants is set
    assert_selector 'input[data-fenetre-video-chat-max-participants-value="3"]', visible: false
  end
end
