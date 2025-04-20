# frozen_string_literal: true

# Pin npm packages by running ./bin/importmap

# Core dependencies - update paths to match how engine serves them
pin '@hotwired/stimulus', to: 'fenetre/vendor/stimulus.min.js', preload: true
pin '@hotwired/stimulus-loading', to: 'stimulus/stimulus-loading.js', preload: true
pin '@hotwired/turbo-rails', to: 'turbo.min.js', preload: true
pin '@hotwired/turbo', to: 'turbo.js', preload: true

# Engine's JavaScript modules with correct namespacing
pin 'fenetre', to: 'fenetre.js', preload: true
pin 'fenetre/application', to: 'fenetre/application.js', preload: true

# Pin controller with correct path to avoid 404 errors
# Updated to match actual file location and engine configuration
pin 'controllers/fenetre/video_chat_controller', to: 'fenetre/controllers/video_chat_controller.js'

# Pin testing libraries and test files (only for development/test)
if Rails.env.development? || Rails.env.test?
  pin 'qunit', to: 'https://code.jquery.com/qunit/qunit-2.20.1.js'
  pin '@rails/actioncable', to: 'actioncable.esm.js'
  pin_all_from 'app/javascript/test', under: 'test'
end
