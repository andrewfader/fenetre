# frozen_string_literal: true

require 'test_helper'

module Fenetre
  class ConnectionStatusTest < ActionView::TestCase
    include Fenetre::VideoChatHelper

    test 'video chat container includes connection status element' do
      html = fenetre_video_chat_container('test-room', 'test-user')

      # Parse the HTML for testing
      doc = Nokogiri::HTML::DocumentFragment.parse(html)

      # Check for connection status element
      status_element = doc.at('[data-fenetre-video-chat-target="connectionStatus"]')

      assert_not_nil status_element, 'Connection status element should exist'

      # Check that it has appropriate default styling
      assert_includes status_element['class'], 'fenetre-connection-status'
    end
  end
end
