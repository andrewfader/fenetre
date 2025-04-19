# frozen_string_literal: true

# Pin npm packages by running ./bin/importmap

# Core dependencies
pin '@hotwired/stimulus', to: 'stimulus.min.js', preload: true
pin '@hotwired/stimulus-loading', to: 'stimulus-loading.js', preload: true
pin '@hotwired/turbo-rails', to: 'turbo.min.js', preload: true
pin '@hotwired/turbo', to: 'turbo.js', preload: true

# Pin this engine's JS modules for use by the host application
pin 'application', to: 'fenetre/application.js'
pin 'controllers/index', to: 'fenetre/controllers/index.js'
pin 'controllers/fenetre/video_chat_controller', to: 'fenetre/controllers/video_chat_controller.js'

# Pin testing libraries and test files (only for development/test)
if Rails.env.development? || Rails.env.test?
  pin 'qunit', to: 'https://code.jquery.com/qunit/qunit-2.20.1.js'
  pin '@rails/actioncable', to: 'actioncable.esm.js'
  pin_all_from 'app/javascript/test', under: 'test'
end
