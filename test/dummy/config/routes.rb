# frozen_string_literal: true

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"

  # Mount the Fenetre engine
  mount Fenetre::Engine => '/fenetre'

  # Add a simple route for testing the helper
  get '/video_chat', to: 'video#show'
  get '/video/test_helper', to: 'video#test_helper'

  # Route for the QUnit test runner
  get '/javascript_tests', to: proc { |_env|
    [200, { 'Content-Type' => 'text/html' }, [File.read(Rails.root.join('public', 'test_runner.html'))]]
  }, constraints: -> { Rails.env.test? || Rails.env.development? }

  # Mount ActionCable for integration/system tests
  mount ActionCable.server => '/cable'

  # Health check endpoints for integration tests
  get '/automatic/status', to: 'health#status'
  get '/automatic/human_status', to: 'health#human_status'
end
