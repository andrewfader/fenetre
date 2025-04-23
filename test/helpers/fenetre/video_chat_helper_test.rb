# frozen_string_literal: true

require 'test_helper'

module Fenetre
  class VideoChatHelperTest < ActionView::TestCase
    # Explicitly include the helper module
    include Fenetre::VideoChatHelper

    test 'fenetre_video_chat_container renders the correct structure and data attributes' do
      room_id = 'room-xyz'
      user_id = 99

      rendered_html = fenetre_video_chat_container(room_id, user_id)
      doc = Nokogiri::HTML::DocumentFragment.parse(rendered_html)

      # Check top-level div
      top_div = doc.at('div')

      assert_not_nil top_div, 'Top-level div should exist'
      assert_equal 'fenetre--video-chat', top_div['data-controller']
      assert_equal user_id.to_s, top_div['data-fenetre-video-chat-user-id-value']

      # Check hidden input for room_id
      hidden_input = top_div.at('input[type="hidden"]')

      assert_not_nil hidden_input, 'Hidden input for room_id should exist'
      assert_equal room_id, hidden_input['value']
      assert_equal 'roomId', hidden_input['data-fenetre-video-chat-target']

      # Check local video element
      local_video = top_div.at('video[data-fenetre-video-chat-target="localVideo"]')

      assert_not_nil local_video, 'Local video element should exist'
      assert local_video.has_attribute?('autoplay'), 'Video should have autoplay attribute'
      assert local_video.has_attribute?('playsinline'), 'Video should have playsinline attribute'
      assert local_video.has_attribute?('muted'), 'Video should have muted attribute'

      # Check remote videos container
      remote_videos_div = top_div.at('div[data-fenetre-video-chat-target="remoteVideos"]')

      assert_not_nil remote_videos_div, 'Remote videos container div should exist'

      # Check headings (optional but good for structure)
      assert_match(/My Video/i, rendered_html)
      assert_match(/Remote Videos/i, rendered_html)
    end

    test 'fenetre_video_chat_container renders required data-controller and targets' do
      html = fenetre_video_chat_container('room123', 'user456')

      assert_includes html, 'data-controller="fenetre--video-chat"'
      assert_includes html, 'data-fenetre-video-chat-target="localVideo"'
      assert_includes html, 'data-fenetre-video-chat-target="remoteVideos"'
      assert_includes html, 'data-fenetre-video-chat-target="roomId"'
      assert_includes html, 'value="room123"'
      assert_includes html, 'data-fenetre-video-chat-user-id-value="user456"'
    end

    test 'fenetre_video_chat_container includes video and remote video containers' do
      html = fenetre_video_chat_container('roomABC', 'userXYZ')

      assert_includes html, '<video'
      assert_includes html, 'data-fenetre-video-chat-target="localVideo"'
      assert_includes html, 'data-fenetre-video-chat-target="remoteVideos"'
    end

    test 'fenetre_video_chat_container renders main container and stylesheet' do
      html = fenetre_video_chat_container('room1', 'user1', theme: 'dark')
      assert_includes html, 'fenetre-video-chat-container'
      assert_includes html, 'fenetre-theme-dark'
      assert_includes html, 'fenetre/video_chat'
    end

    test 'fenetre_video_chat_container supports light theme' do
      html = fenetre_video_chat_container('room2', 'user2', theme: 'light')
      assert_includes html, 'fenetre-theme-light'
    end

    test 'video_chat_main_container renders all sections' do
      html = send(:video_chat_main_container, 'roomX', 'userY', 'dark')
      %w[Participants My\ Video Remote\ Videos Chat].each do |heading|
        assert_match(/<h3[^>]*>#{heading}/, html)
      end
      assert_includes html, 'fenetre-connection-status'
      assert_includes html, 'fenetre-controls'
      assert_includes html, 'fenetre-video-section'
      assert_includes html, 'fenetre-chat-container'
    end

    test 'connection_status_indicator renders correct div' do
      html = send(:connection_status_indicator)
      assert_includes html, 'Connecting...'
      assert_includes html, 'fenetre-connection-status'
    end

    test 'hidden_room_id_input renders hidden input' do
      html = send(:hidden_room_id_input, 'room42')
      assert_includes html, 'type="hidden"'
      assert_includes html, 'value="room42"'
      assert_includes html, 'data-fenetre-video-chat-target="roomId"'
    end

    test 'section_heading renders h3' do
      html = send(:section_heading, 'Test Heading')
      assert_match(/<h3[^>]*>Test Heading<\/h3>/, html)
    end

    test 'participants_list renders ul' do
      html = send(:participants_list)
      assert_match(/<ul[^>]*id="fenetre-participant-list"/, html)
    end

    test 'local_video_section renders video tag' do
      html = send(:local_video_section)
      assert_includes html, '<video'
      assert_includes html, 'data-fenetre-video-chat-target="localVideo"'
      assert_includes html, 'autoplay'
      assert_includes html, 'playsinline'
      assert_includes html, 'muted'
    end

    test 'media_control_section renders all control buttons' do
      html = send(:media_control_section)
      %w[Toggle\ Video Toggle\ Audio Share\ Screen].each do |label|
        assert_match(/<button[^>]*>#{label}/, html)
      end
    end

    test 'toggle_button renders button with action' do
      html = send(:toggle_button, 'TestBtn', 'doAction')
      assert_match(/<button[^>]*data-action="fenetre--video-chat#doAction"/, html)
      assert_includes html, 'TestBtn'
    end

    test 'remote_videos_section renders remoteVideos target' do
      html = send(:remote_videos_section)
      assert_includes html, 'data-fenetre-video-chat-target="remoteVideos"'
    end

    test 'chat_section renders chat messages and input' do
      html = send(:chat_section)
      assert_includes html, 'fenetre-chat-messages'
      assert_includes html, 'fenetre-chat-input-container'
    end

    test 'chat_messages renders chatMessages target' do
      html = send(:chat_messages)
      assert_includes html, 'data-fenetre-video-chat-target="chatMessages"'
    end

    test 'chat_input_container renders input and send button' do
      html = send(:chat_input_container)
      assert_includes html, 'type="text"'
      assert_includes html, 'placeholder="Type your message..."'
      assert_includes html, 'fenetre-chat-send-button'
    end
  end
end
