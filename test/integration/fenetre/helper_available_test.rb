# frozen_string_literal: true

# test/integration/helper_availability_test.rb
require 'test_helper'

class HelperAvailabilityTest < ActionDispatch::IntegrationTest
  test 'video_chat_helper is available in views' do
    # Create a temporary controller to test the helper availability
    controller = ActionController::Base.new
    controller.extend(ActionView::Helpers)
    controller.extend(Fenetre::VideoChatHelper)

    # Test if the method exists
    assert controller.respond_to?(:fenetre_video_chat_container),
           'fenetre_video_chat_container helper should be available'
  end
end

class HelperAvailableTest < ActionDispatch::IntegrationTest
  test 'fenetre_video_chat_container helper is available in views' do
    get '/video/test_helper'
    assert_response :success
    assert_includes @response.body, 'fenetre-video-chat-container',
                    'Helper output should be present in the rendered view'
  end
end
