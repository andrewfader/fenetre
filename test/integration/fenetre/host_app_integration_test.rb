# frozen_string_literal: true

require 'test_helper'

class IntegrationHostAppTest < ActionDispatch::IntegrationTest
  test 'video_chat helper renders properly in host application' do
    # Create a test controller in the dummy app
    Object.const_set('TestHostController', Class.new(ApplicationController) do
      include Fenetre::VideoChatHelper
      def index
        render inline: "<%= fenetre_video_chat_container('test_room_123', 'test_user_456') %>"
      end
    end)

    # Add a route for our test controller without overwriting all routes
    with_routing do |set|
      set.draw do
        get '/test_host', to: 'test_host#index'
      end
      # Make a request to the controller
      get '/test_host'

      # Ensure the response is successful
      assert_response :success

      # Verify the HTML structure contains expected elements using Nokogiri
      doc = Nokogiri::HTML(response.body)
      assert doc.at_css('div[data-controller="fenetre--video-chat"]'), "Expected video chat container"
      assert doc.at_css('input[data-fenetre-video-chat-target="roomId"][value="test_room_123"]'), "Expected roomId input"
    end

    # Clean up
    Object.send(:remove_const, :TestHostController)
  end

  test 'ActionCable is properly mounted in host application' do
    # Check if ActionCable is mounted at /cable (loosen matcher for Rails 7/8)
    assert Rails.application.routes.routes.any? { |route|
      route.path.spec.to_s =~ %r{^/cable}
    }, 'ActionCable should be mounted at /cable'
  end

  test 'health check endpoints are accessible' do
    get '/automatic/status'
    assert_response :success
    assert response.content_type.start_with?('application/json')
    json = JSON.parse(response.body)
    assert_equal 'ok', json['status']
    assert_equal Fenetre::VERSION, json['version']

    get '/automatic/human_status'
    assert_response :success
    assert response.content_type.start_with?('text/html')
    assert_match(/Fenetre Status/, response.body)
  end
end
