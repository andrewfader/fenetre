# frozen_string_literal: true

Fenetre::Engine.routes.draw do
  get '/status', to: 'status#show'
  get '/human_status', to: 'status#human'
end
