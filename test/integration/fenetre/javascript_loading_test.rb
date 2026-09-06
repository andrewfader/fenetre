# frozen_string_literal: true

require 'test_helper'

module Fenetre
  class JavascriptLoadingTest < ActionDispatch::IntegrationTest
    test 'all importmap assets are served with JavaScript MIME types and real content' do
      get '/video_chat'
      pins = JSON.parse(Nokogiri::HTML(response.body).at_css('script[type="importmap"]').text).fetch('imports')
      pins.values.uniq.each do |path|
        get path
        assert_response :success
        assert_match(/javascript/, response.media_type, path)
        refute_empty response.body
      end
    end
  end
end
