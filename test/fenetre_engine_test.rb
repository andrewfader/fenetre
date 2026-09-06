# frozen_string_literal: true

require 'test_helper'

class FenetreEngineTest < ActionDispatch::IntegrationTest
  test 'engine composes its import map without replacing the host entrypoint' do
    get '/video_chat'
    assert_response :success
    doc = Nokogiri::HTML(response.body)
    pins = JSON.parse(doc.at_css('script[type="importmap"]').text).fetch('imports')
    assert_match(%r{/assets/application-}, pins.fetch('application'))
    %w[fenetre @hotwired/stimulus @rails/actioncable fenetre/controllers/video_chat_controller].each do |name|
      get pins.fetch(name)
      assert_response :success
      assert_match(/javascript/, response.media_type)
      refute_empty response.body
    end
  end

  test 'Action Cable is mounted once and engine routes survive reloading' do
    # Rails draws routes lazily, so reload what a running app would already have drawn.
    get '/fenetre/status'
    assert_response :success

    Rails.application.reload_routes!
    cable_routes = Rails.application.routes.routes.select { |route| route.path.spec.to_s.start_with?('/cable') }
    assert_equal 1, cable_routes.size
    get '/fenetre/status'
    assert_response :success
    assert_equal Fenetre::VERSION, response.parsed_body['version']
  end
end
