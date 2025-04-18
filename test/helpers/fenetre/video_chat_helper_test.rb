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
  end
end
