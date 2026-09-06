# frozen_string_literal: true

pin 'application'
pin '@hotwired/turbo-rails', to: 'turbo.min.js'
pin '@hotwired/stimulus', to: 'stimulus.min.js'
pin '@hotwired/stimulus-loading', to: 'stimulus-loading.js'

if Rails.env.test?
  pin 'test/test_runner', to: 'test/test_runner.js'
  pin 'test/video_chat_controller_test', to: 'test/video_chat_controller_test.js'
end
