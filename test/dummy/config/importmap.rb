# frozen_string_literal: true

# Pin npm packages by running ./bin/importmap

# Core dependencies (used by the engine)
pin '@hotwired/turbo-rails', to: 'turbo.min.js', preload: true
pin '@hotwired/stimulus', to: 'stimulus.min.js', preload: true
pin 'stimulus', to: '@hotwired/stimulus', preload: true
pin '@hotwired/stimulus-loading', to: 'stimulus-loading.js', preload: true

# Host application's entry point
pin 'dummy_app', to: 'application.js', preload: true
pin 'application', to: 'application.js', preload: true

# Pin Fenetre engine assets
pin 'fenetre', to: 'fenetre.js', preload: true
pin 'fenetre/application', to: 'fenetre/application.js', preload: true
pin 'fenetre/controllers', to: 'fenetre/controllers/index.js', preload: true
pin 'fenetre/controllers/video_chat_controller', to: 'fenetre/controllers/video_chat_controller.js', preload: true
pin 'controllers/fenetre/video_chat_controller', to: 'fenetre/controllers/video_chat_controller.js', preload: true

# Use the directory structure for controllers
pin_all_from 'app/javascript/controllers', under: 'controllers'
pin_all_from 'app/javascript', under: 'dummy_app'
