# frozen_string_literal: true

require 'test_helper'

module Fenetre
  class JavascriptLoadingTest < ActionDispatch::IntegrationTest
    test 'javascript files load with correct MIME types' do
      # This test checks if JavaScript files are served with the correct MIME type

      # Check Stimulus based on importmap pin and propshaft path
      get '/assets/stimulus.min.js' # Reverted path based on importmap pin

      assert_equal 'application/javascript', response.content_type,
                   'Stimulus.min.js should be served with application/javascript MIME type'

      # Check controller path (assuming it's mapped correctly by propshaft/importmap)
      get '/assets/fenetre/controllers/video_chat_controller.js' # Path seems correct based on importmap

      assert_equal 'application/javascript', response.content_type,
                   'Video chat controller should be served with application/javascript MIME type'
    end
  end
end
