# frozen_string_literal: true

# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

# Load required libraries
require 'rails'
require 'action_cable'
require 'action_view'
require 'active_support'
require 'minitest/autorun'
require 'nokogiri'

# Load the gem
require 'fenetre'

# Explicitly require the helper file
require File.expand_path('../app/helpers/fenetre/video_chat_helper', __dir__)
require File.expand_path('../app/channels/fenetre/video_chat_channel', __dir__)

# Simple user class for testing
class User
  attr_reader :id

  def initialize(id)
    @id = id
  end

  def logged_in?
    true
  end
end

# Define ApplicationCable namespace for tests
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    # Define a constructor that doesn't require arguments for testing
    def initialize(server = nil, env = nil)
      # No-op for tests
    end
  end

  class Channel < ActionCable::Channel::Base
  end
end

# Configure Action Cable for testing
ActionCable.server.config.logger = Logger.new(nil)
ActionCable.server.config.cable = { adapter: 'async' }

# Add rejection tracking capability to ActionCable::Channel::Base
ActionCable::Channel::Base.class_eval do
  def reject
    @rejected = true
    super
  end

  def rejected?
    @rejected == true
  end
end

# Patch ActionCable::Channel::Base for test environment (only once)
unless ENV['REAL_CABLE'] && defined?(@@fenetre_patch_applied)
  @@fenetre_patch_applied = true
  ActionCable::Channel::Base.class_eval do
    # Track streams for assertions
    def stream_from(stream, *)
      @_streams ||= []
      @_streams << stream
    end

    def reject
      @_rejected = true
    end

    def rejected?
      !!@_rejected
    end

    def confirmed?
      !rejected?
    end
  end
end

# Custom Channel test case with minimal testing utilities
module ActionCable
  module Channel
    class TestCase < ActiveSupport::TestCase
      # Storage for broadcasts
      @@broadcasts = Hash.new { |h, k| h[k] = [] }

      # Override broadcast method for testing
      ActionCable::Server::Broadcasting.class_eval do
        alias_method :original_broadcast, :broadcast if method_defined?(:broadcast)

        def broadcast(broadcasting, message)
          ActionCable::Channel::TestCase.add_broadcast(broadcasting, message)
          original_broadcast(broadcasting, message) if defined?(original_broadcast)
        end
      end

      def self.add_broadcast(broadcasting, message)
        @@broadcasts[broadcasting] << message
      end

      def self.clear_broadcasts
        @@broadcasts.clear
      end

      setup do
        self.class.clear_broadcasts
        # Only set current_user if not already set by the test
        @connection ||= stub_connection(current_user: User.new(1))
        @subscription = nil
      end

      # Test helpers
      def stub_connection(identifiers = {})
        connection = ApplicationCable::Connection.allocate
        connection.instance_variable_set(:@identifiers, identifiers.keys)
        identifiers.each do |identifier, value|
          if value.nil?
            # Remove method if value is nil
            connection.singleton_class.send(:define_method, identifier) { nil }
          else
            connection.instance_variable_set("@#{identifier}", value)
            connection.define_singleton_method(identifier) do
              instance_variable_get("@#{identifier}")
            end
          end
        end
        connection
      end

      def subscribe(params = {})
        channel_class = self.class.name.sub(/Test$/, '').constantize
        @subscription = channel_class.new(@connection, 'test_id', params.with_indifferent_access)

        # Call subscribe method and track streams
        @subscription.send(:subscribed)
        @subscription
      end

      def unsubscribe
        @subscription.send(:unsubscribed)
      end

      def perform(action, data = {})
        @subscription.send(action, data)
      end

      def assert_has_stream(stream)
        assert @subscription.instance_variable_get(:@_streams).include?(stream),
               "Expected subscription to be streaming from #{stream}"
      end

      attr_reader :subscription

      def assert_broadcasts(stream, number)
        broadcasts_before = broadcasts(stream).size
        yield
        broadcasts_after = broadcasts(stream).size
        assert_equal number, broadcasts_after - broadcasts_before,
                     "Expected #{number} broadcasts, but got #{broadcasts_after - broadcasts_before}"
      end

      def broadcasts(stream)
        @@broadcasts[stream] || []
      end
    end
  end
end

module ActionView
  class TestCase < ActiveSupport::TestCase
    include ActionView::Helpers
    # Explicitly include the helper
    include Fenetre::VideoChatHelper
  end
end
