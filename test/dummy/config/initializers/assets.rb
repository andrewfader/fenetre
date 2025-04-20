# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
# Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Add Fenetre engine's vendor JS directory to the asset load path for Propshaft
if defined?(Rails.application.config.assets) && Rails.application.config.assets.respond_to?(:paths)
  # Add both vendor paths to ensure Stimulus is found
  Rails.application.config.assets.paths << Fenetre::Engine.root.join('app/assets/javascripts/fenetre/vendor')
  Rails.application.config.assets.paths << Fenetre::Engine.root.join('app/assets/javascripts/stimulus')
  
  # Set the proper MIME type for JavaScript files
  Rails.application.config.assets.configure do |config|
    config.mime_types['.js'] = 'application/javascript'
  end
  
  # Ensure we precompile both the namespaced and root paths for Stimulus to support both importmap and direct asset access
  Rails.application.config.assets.precompile += %w[
    stimulus.min.js
    fenetre/vendor/stimulus.min.js
    fenetre/controllers/index.js
    fenetre/application.js
    fenetre/controllers/video_chat_controller.js
  ]
elsif defined?(Rails.application.config.propshaft)
  Rails.application.config.propshaft.paths << Fenetre::Engine.root.join('app/assets/javascripts/fenetre/vendor')
  Rails.application.config.propshaft.paths << Fenetre::Engine.root.join('app/assets/javascripts/stimulus')
end
