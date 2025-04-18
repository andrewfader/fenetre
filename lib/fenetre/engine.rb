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

    # Set up asset loading
    initializer 'fenetre.assets' do |app|
      # Add JavaScript assets
      app.config.respond_to?(:assets) &&
        app.config.assets.precompile += %w[fenetre/video_chat_controller.js]
    end

    # Add Stimulus controllers to importmap if available
    initializer 'fenetre.importmap', before: 'importmap' do |app|
      if app.config.respond_to?(:importmap) && app.config.importmap.respond_to?(:pin_all_from)
        app.config.importmap.pin_all_from(
          Fenetre::Engine.root.join('app/javascript/controllers'),
          under: 'controllers'
        )
      end
    end

    # Include ActionCable in the host application
    initializer 'fenetre.action_cable' do
      # Register the channel path instead of using channel_class_names
      if defined?(ActionCable) && defined?(ActionCable.server)
        action_cable_paths = Array(Rails.root.join('app/channels'))
        action_cable_paths << Fenetre::Engine.root.join('app/channels')
        ActionCable.server.config.cable ||= {}
        if ActionCable.server.config.instance_variable_defined?(:@paths)
          ActionCable.server.config.send(:remove_instance_variable,
                                         :@paths)
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
    end
  end
end

# Mountable status engine for health checks
class AutomaticEngine < ::Rails::Engine
  isolate_namespace Fenetre::Automatic
  initializer 'fenetre.automatic_engine' do |app|
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
