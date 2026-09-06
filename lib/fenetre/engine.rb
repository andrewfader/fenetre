# frozen_string_literal: true

require 'rails'
require 'action_cable/engine'
require 'action_view/railtie'
require 'turbo-rails'
require 'stimulus-rails'
require 'propshaft'
require 'importmap-rails'
require_relative 'version'

module Fenetre
  class Engine < ::Rails::Engine
    isolate_namespace Fenetre

    initializer 'fenetre.importmap', before: 'importmap' do |app|
      app.config.importmap.paths << root.join('config/importmap.rb')
      app.config.importmap.cache_sweepers << root.join('app/assets/javascripts')
    end

    initializer 'fenetre.helpers' do
      ActiveSupport.on_load(:action_controller_base) do
        helper Fenetre::VideoChatHelper
      end
    end
  end
end
