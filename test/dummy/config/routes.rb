# frozen_string_literal: true

Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Mount the Fenetre engine
  mount Fenetre::Engine => '/fenetre'

  # Add routes for testing the helper
  get '/video_chat', to: 'video#show'
  get '/video/test_helper', to: 'video#test_helper'

  # Route for the QUnit test runner
  get '/javascript_tests', to: 'video#javascript_tests'

  # Mount AutomaticEngine for health check endpoints
  mount Fenetre::Engine => '/automatic', as: :automatic
end
