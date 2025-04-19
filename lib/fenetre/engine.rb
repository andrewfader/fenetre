# frozen_string_literal: true

require 'rails'
require 'action_cable/engine'
require 'action_view/railtie'
require 'turbo-rails'
require 'stimulus-rails'
require_relative 'version'

# Explicitly require helper to ensure it's loaded before the engine initializers run
require_relative '../../app/helpers/fenetre/video_chat_helper'

module Fenetre
  module Automatic; end

  class Engine < ::Rails::Engine
    isolate_namespace Fenetre

    # Mount Action Cable server automatically
    initializer 'fenetre.mount_cable', after: :load_config_initializers do |app|
      # Check if Action Cable route is already mounted
      has_cable_route = app.routes.routes.any? { |route| route.app == ActionCable.server }

      unless has_cable_route
        app.routes.append do
          mount ActionCable.server => '/cable'
        end
        # Removed to avoid Devise/Warden and Rails 8 issues
      end
    end

    # Add Stimulus controllers to importmap if available
    initializer 'fenetre.importmap', before: 'importmap' do |app|
      # Check if the host app uses importmap-rails
      if app.config.respond_to?(:importmap)
        # Pin the engine's controllers directory.
        # Controllers will be loaded automatically by the host app's Stimulus setup
        # if it imports controllers (e.g., import "./controllers").
        # The controllers will be available under 'controllers/fenetre/...'
        app.config.importmap.pin_all_from Fenetre::Engine.root.join('app/javascript/controllers'),
                                          under: 'controllers/fenetre', to: 'fenetre/controllers'

        # Pin the engine's main JS entry point if needed, or individual files.
        # This makes `import 'fenetre'` or specific files available.
        # Pinning the directory allows importing specific files like `import 'fenetre/some_module'`
        app.config.importmap.pin_all_from Fenetre::Engine.root.join('app/assets/javascripts/fenetre'),
                                          under: 'fenetre', to: 'fenetre'

        # Ensure the engine's assets are served
        app.config.assets.paths << Fenetre::Engine.root.join('app/assets/javascripts')
        # Add stylesheets if needed via assets
        # app.config.assets.paths << Fenetre::Engine.root.join('app/assets/stylesheets')
        # app.config.assets.precompile += %w( fenetre/video_chat.css ) # If using sprockets for CSS
      else
        # Fallback or warning if importmap is not used by the host app
        Rails.logger.warn "Fenetre requires importmap-rails to automatically load JavaScript controllers. Please install importmap-rails or manually include Fenetre's JavaScript."
      end
    end

    # Include ActionCable in the host application - ensure it doesn't interfere with Devise
    initializer 'fenetre.action_cable', after: :load_config_initializers do
      # Register the channel path instead of using channel_class_names
      if defined?(ActionCable) && defined?(ActionCable.server)
        action_cable_paths = Array(Rails.root.join('app/channels'))
        action_cable_paths << Fenetre::Engine.root.join('app/channels')

        # Only configure if ActionCable server is present and not already configured
        if ActionCable.server.config.cable
          # Use safer method to update paths without removing existing configuration
          if ActionCable.server.config.respond_to?(:paths=)
            ActionCable.server.config.paths = action_cable_paths
          elsif ActionCable.server.config.instance_variable_defined?(:@paths)
            # Carefully update paths without affecting other configurations
            ActionCable.server.config.instance_variable_set(:@paths, action_cable_paths)
          end
        end
      end
    end

    # Register helpers
    initializer 'fenetre.helpers' do
      ActiveSupport.on_load(:action_controller_base) do
        helper Fenetre::VideoChatHelper
      end
      ActiveSupport.on_load(:action_view) do
        include Fenetre::VideoChatHelper
      end
      # Explicitly include in base classes for reliability
      ::ActionController::Base.helper Fenetre::VideoChatHelper if defined?(::ActionController::Base)
      ::ActionView::Base.include Fenetre::VideoChatHelper if defined?(::ActionView::Base)
    end
  end
end

# Mountable status engine for health checks - ensure it doesn't conflict with other gems
class AutomaticEngine < ::Rails::Engine
  isolate_namespace Fenetre::Automatic

  # Use a lower priority to ensure it loads after authentication engines
  initializer 'fenetre.automatic_engine', after: :load_config_initializers do |app|
    # No-op, just for mounting
  end
end

# Add routes for status in the automatic engine
AutomaticEngine.routes.draw do
  get '/status', to: proc { |_env|
    [200, { 'Content-Type' => 'application/json' }, [{ status: 'ok', time: Time.now.utc.iso8601, version: Fenetre::VERSION }.to_json]]
  }
  get '/human_status', to: proc { |_env|
    body = <<-HTML
        <html><head><title>Fenetre Status</title></head><body>
        <h1>Fenetre Status</h1>
        <ul>
          <li>Status: <strong>ok</strong></li>
          <li>Time: #{Time.now.utc.iso8601}</li>
          <li>Version: #{Fenetre::VERSION}</li>
        </ul>
        </body></html>
    HTML
    [200, { 'Content-Type' => 'text/html' }, [body]]
  }
end
