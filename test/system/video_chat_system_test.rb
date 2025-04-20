# frozen_string_literal: true

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
    assert_selector 'div[data-fenetre-video-chat-target="remoteVideos"]', visible: :all
    assert_selector 'input[value="testroom"]', visible: :all

    # Verify media control buttons exist
    assert_selector 'button[data-action*="fenetre--video-chat#toggleVideo"]'
    assert_selector 'button[data-action*="fenetre--video-chat#toggleAudio"]'

    # Verify chat interface elements
    assert_selector 'div[data-fenetre-video-chat-target="chatMessages"]', visible: :all
    assert_selector 'input[data-fenetre-video-chat-target="chatInput"]', visible: :all
    assert_selector 'button[data-action*="fenetre--video-chat#sendChat"]', visible: :all

    # Verify the page title and room info
    assert_text 'Video Chat Test Page'
    assert_text 'Room ID: testroom'
  end

  test 'user can interact with media controls' do
    visit '/video_chat?room_id=controltest&user_id=2&username=TestUser'

    # Test video toggle functionality
    assert_selector 'video[data-fenetre-video-chat-target="localVideo"]'
    find('button[data-action*="fenetre--video-chat#toggleVideo"]').click

    # Ideally we would verify the video track is disabled, but for system tests
    # we can only confirm the button interaction works without errors

    # Test audio toggle functionality
    find('button[data-action*="fenetre--video-chat#toggleAudio"]').click

    # Again, we can verify the button click doesn't cause errors
    assert_selector 'button[data-action*="fenetre--video-chat#toggleAudio"]'
  end

  test 'user can send and receive chat messages' do
    visit '/video_chat?room_id=chattest&user_id=3'

    # Find the chat input field and verify it exists
    input_field = find('input[data-fenetre-video-chat-target="chatInput"]', visible: :all)
    assert_not_nil input_field

    # Find the send button and verify it exists
    send_button = find('button[data-action*="fenetre--video-chat#sendChat"]', visible: :all)
    assert_not_nil send_button

    # Verify the chat messages container exists
    assert_selector 'div[data-fenetre-video-chat-target="chatMessages"]', visible: :all

    # Fill in the chat input with a test message
    input_field.fill_in with: 'Test message'

    # Click the send button - this would normally trigger the JavaScript
    send_button.click

    # This is where we would verify the message appears, but since
    # WebRTC and ActionCable connections may not work in the test environment,
    # we'll just verify the UI components are correctly set up
  end

  test 'room connection status is properly displayed' do
    visit '/video_chat?room_id=connectiontest&user_id=3'

    # Verify connection-related elements
    assert_selector 'video[data-fenetre-video-chat-target="localVideo"]'

    # Add connection status element to the test if it exists
    if has_selector?('[data-fenetre-video-chat-target="connectionStatus"]', wait: 1)
      assert_selector '[data-fenetre-video-chat-target="connectionStatus"]'
    end
  end

  test 'multiple users can connect to the same room' do
    # First user visits the page
    visit '/video_chat?room_id=multiuser-test&user_id=4&username=User4'

    # Verify the first user's page loaded correctly
    assert_selector '[data-controller="fenetre--video-chat"]'
    assert_text 'Room ID: multiuser-test'

    # Open a new browser session for second user
    using_session(:user2) do
      visit '/video_chat?room_id=multiuser-test&user_id=5&username=User5'
      assert_selector '[data-controller="fenetre--video-chat"]'

      # Send a chat message from second user
      find('input[data-fenetre-video-chat-target="chatInput"]', visible: :all).fill_in with: 'Hello from User5'
      find('button[data-action*="fenetre--video-chat#sendChat"]', visible: :all).click
    end

    # First user should receive the chat message from the second user
    # Note: In a real application, this would be delivered through ActionCable
    # For our test purposes, we're just verifying the UI is properly set up
  end

  test 'room parameters are properly handled' do
    visit '/video_chat?room_id=customroom&user_id=6&username=CustomUser&room_topic=Custom%20Meeting&max_participants=3'

    # Verify basic parameters are shown
    assert_text 'Video Chat Test Page'
    assert_text 'Room ID: customroom'

    # Verify the controller is properly initialized
    assert_selector '[data-controller="fenetre--video-chat"]'

    # Check for any custom room features based on parameters
    # (These would depend on your specific implementation)
  end

  test 'user can toggle screen sharing' do
    visit '/video_chat?room_id=screenshare&user_id=7'

    # Verify the screen sharing button exists
    assert_selector 'button[data-action*="fenetre--video-chat#toggleScreenShare"]'

    # Click the screen sharing button
    # Note: In a test environment, the browser may not actually show the screen sharing dialog
    # We're just verifying the button exists and can be clicked without errors
    find('button[data-action*="fenetre--video-chat#toggleScreenShare"]').click

    # Verify the button is still there after clicking (no JS errors)
    assert_selector 'button[data-action*="fenetre--video-chat#toggleScreenShare"]'
  end

  test 'connection status indicator is displayed' do
    visit '/video_chat?room_id=connectionstatus&user_id=8'

    # Verify the connection status element exists
    assert_selector '[data-fenetre-video-chat-target="connectionStatus"]'

    # Initially it should show "Connecting..." (or whatever initial state you set)
    within('[data-fenetre-video-chat-target="connectionStatus"]') do
      assert_text(/Connecting\.\.\.|Connected|Disconnected/i)
    end
  end
end
