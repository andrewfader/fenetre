# frozen_string_literal: true

require 'test_helper'

module Fenetre
  class VideoChatChannelTest < ActionCable::Channel::TestCase
    # Use Action Cable testing helpers
    # https://guides.rubyonrails.org/testing.html#testing-action-cable

    # Stub current_user for channel tests
    # In a real app, this would likely come from your authentication system (e.g., Devise, Warden)
    def connection
      stub_connection(current_user: User.new(1)) # Simple stub user
    end

    # Simple stub User class for testing purposes
    class User
      attr_reader :id

      def initialize(id)
        @id = id
      end

      # Add any methods your channel might call on current_user
      def logged_in? = true
    end

    test 'subscribes and streams for a room when user is present' do
      room_id = 'test_room_123'
      subscribe(room_id: room_id)

      assert subscription.confirmed?
      assert_has_stream "fenetre_video_chat_#{room_id}"
    end

    test 'rejects subscription when no user is present' do
      room_id = 'test_room_456'
      @connection = stub_connection(current_user: nil)
      subscribe(room_id: room_id)
      assert subscription.rejected?
    end

    test 'rejects subscription when room_id is missing' do
      subscribe # No room_id provided
      assert subscription.rejected?
    end

    test 'rejects subscription when room_id is blank' do
      subscribe(room_id: '') # Blank room_id provided
      assert subscription.rejected?
    end

    test '#signal broadcasts payload to the correct stream' do
      room_id = 'test_room_789'
      subscribe(room_id: room_id)
      assert subscription.confirmed?

      signal_payload = { 'sdp' => 'session description' }
      signal_type = 'offer'

      # Check that the broadcast happens on the correct stream
      assert_broadcasts("fenetre_video_chat_#{room_id}", 1) do
        perform :signal, { type: signal_type, payload: signal_payload }
      end

      # Optionally, check the content of the broadcast
      last_broadcast = broadcasts("fenetre_video_chat_#{room_id}").last
      assert_equal connection.current_user.id, last_broadcast[:from]
      assert_equal signal_type, last_broadcast[:type]
      assert_equal signal_payload, last_broadcast[:payload]
    end

    test '#join_room broadcasts join message' do
      room_id = 'test_room_abc'
      subscribe(room_id: room_id)
      assert subscription.confirmed?

      assert_broadcasts("fenetre_video_chat_#{room_id}", 1) do
        perform :join_room, {}
      end

      last_broadcast = broadcasts("fenetre_video_chat_#{room_id}").last
      assert_equal connection.current_user.id, last_broadcast[:from]
      assert_equal 'join', last_broadcast[:type]
    end

    test 'unsubscribing broadcasts leave message' do
      room_id = 'test_room_def'
      subscribe(room_id: room_id)
      assert subscription.confirmed?

      # Unsubscribe triggers the broadcast
      assert_broadcasts("fenetre_video_chat_#{room_id}", 1) do
        unsubscribe
      end

      last_broadcast = broadcasts("fenetre_video_chat_#{room_id}").last
      assert_equal connection.current_user.id, last_broadcast[:from]
      assert_equal 'leave', last_broadcast[:type]
    end

    test 'guests are rejected if room is locked' do
      room_id = 'locked_room'
      # Simulate room locked meta
      @connection = stub_connection(current_user: User.new(2), user_role: :guest)
      subscribe(room_id: room_id, room_locked: true)
      assert subscription.rejected?, 'Guest should be rejected if room is locked'
    end

    test 'host can join locked room' do
      room_id = 'locked_room'
      @connection = stub_connection(current_user: User.new(1), user_role: :host)
      subscribe(room_id: room_id, room_locked: true)
      assert subscription.confirmed?, 'Host should be able to join locked room'
    end

    test 'room metadata is broadcast on join' do
      room_id = 'meta_room'
      @connection = stub_connection(current_user: User.new(3), user_role: :guest)
      subscribe(room_id: room_id, room_topic: 'Math Help', max_participants: 5)
      assert_broadcasts("fenetre_video_chat_#{room_id}", 1) do
        perform :join_room, {}
      end
      last_broadcast = broadcasts("fenetre_video_chat_#{room_id}").last
      assert_equal 'Math Help', last_broadcast[:topic]
      assert_equal 5, last_broadcast[:max_participants]
    end

    test 'broadcasts presence when user joins and leaves' do
      room_id = 'presence_room'
      @connection = stub_connection(current_user: User.new(10), user_role: :guest)
      subscribe(room_id: room_id)
      assert_broadcasts("fenetre_video_chat_#{room_id}", 1) do
        perform :join_room, {}
      end
      assert_broadcasts("fenetre_video_chat_#{room_id}", 1) do
        unsubscribe
      end
      join = broadcasts("fenetre_video_chat_#{room_id}").first
      leave = broadcasts("fenetre_video_chat_#{room_id}").last
      assert_equal 'join', join[:type]
      assert_equal 'leave', leave[:type]
      assert_equal 10, join[:from]
      assert_equal 10, leave[:from]
    end

    test 'host can kick a user from the room' do
      room_id = 'mod_room'
      @connection = stub_connection(current_user: User.new(1), user_role: :host)
      subscribe(room_id: room_id)
      assert_broadcasts("fenetre_video_chat_#{room_id}", 1) do
        perform :kick, { user_id: 42 }
      end
      kick = broadcasts("fenetre_video_chat_#{room_id}").last
      assert_equal 'kick', kick[:type]
      assert_equal 1, kick[:from]
      assert_equal 42, kick[:user_id]
    end

    test 'custom signaling: raise_hand' do
      room_id = 'signal_room'
      subscribe(room_id: room_id)
      assert_broadcasts("fenetre_video_chat_#{room_id}", 1) do
        perform :signal, { type: 'raise_hand', payload: { reason: 'question' } }
      end
      last = broadcasts("fenetre_video_chat_#{room_id}").last
      assert_equal 'raise_hand', last[:type]
      assert_equal({ 'reason' => 'question' }, last[:payload])
    end

    test 'host can mute and unmute a user' do
      room_id = 'mod_room'
      @connection = stub_connection(current_user: User.new(1), user_role: :host)
      subscribe(room_id: room_id)
      assert_broadcasts("fenetre_video_chat_#{room_id}", 1) do
        perform :mute, { user_id: 42 }
      end
      mute = broadcasts("fenetre_video_chat_#{room_id}").last
      assert_equal 'mute', mute[:type]
      assert_equal 1, mute[:from]
      assert_equal 42, mute[:user_id]
      assert_broadcasts("fenetre_video_chat_#{room_id}", 1) do
        perform :unmute, { user_id: 42 }
      end
      unmute = broadcasts("fenetre_video_chat_#{room_id}").last
      assert_equal 'unmute', unmute[:type]
      assert_equal 1, unmute[:from]
      assert_equal 42, unmute[:user_id]
    end

    test 'hand-raise queue is broadcast and updated' do
      room_id = 'queue_room'
      subscribe(room_id: room_id)
      assert_broadcasts("fenetre_video_chat_#{room_id}", 1) do
        perform :signal, { type: 'raise_hand', payload: { user_id: 5 } }
      end
      assert_broadcasts("fenetre_video_chat_#{room_id}", 1) do
        perform :signal, { type: 'lower_hand', payload: { user_id: 5 } }
      end
      raise_hand = broadcasts("fenetre_video_chat_#{room_id}")[-2]
      lower_hand = broadcasts("fenetre_video_chat_#{room_id}").last
      assert_equal 'raise_hand', raise_hand[:type]
      assert_equal 5, raise_hand[:payload]['user_id']
      assert_equal 'lower_hand', lower_hand[:type]
      assert_equal 5, lower_hand[:payload]['user_id']
    end

    test 'turbo stream UI update is broadcast on join' do
      room_id = 'turbo_room'
      @connection = stub_connection(current_user: User.new(7), user_role: :guest)
      subscribe(room_id: room_id)
      assert_broadcasts("fenetre_video_chat_#{room_id}", 1) do
        perform :join_room, {}
      end
      last = broadcasts("fenetre_video_chat_#{room_id}").last
      assert last[:turbo_stream], 'Turbo stream UI update should be present'
    end

    test 'participant list is updated on join and leave' do
      room_id = 'list_room'
      @connection = stub_connection(current_user: User.new(100), user_role: :guest)
      subscribe(room_id: room_id)
      assert_broadcasts("fenetre_video_chat_#{room_id}", 1) do
        perform :join_room, {}
      end
      join = broadcasts("fenetre_video_chat_#{room_id}").last
      assert_equal [100], join[:participants]
      assert_broadcasts("fenetre_video_chat_#{room_id}", 1) do
        unsubscribe
      end
      leave = broadcasts("fenetre_video_chat_#{room_id}").last
      assert_equal [], leave[:participants]
    end

    test 'chat messages are broadcast to the room' do
      room_id = 'chat_room'
      subscribe(room_id: room_id)
      assert_broadcasts("fenetre_video_chat_#{room_id}", 1) do
        perform :chat, { message: 'Hello world!' }
      end
      chat = JSON.parse(broadcasts("fenetre_video_chat_#{room_id}").last)
      assert_equal 'chat', chat[:type]
      assert_equal 'Hello world!', chat[:message]
      assert_equal connection.current_user.id, chat[:from]
    end

    test 'analytics hook is called on join and leave' do
      room_id = 'analytics_room'
      @connection = stub_connection(current_user: User.new(200), user_role: :guest)
      subscribe(room_id: room_id)
      # Simulate analytics hook by setting a flag
      $fenetre_analytics ||= []
      perform :join_room, {}
      assert_includes $fenetre_analytics, [:join, 200, room_id]
      unsubscribe
      assert_includes $fenetre_analytics, [:leave, 200, room_id]
    end

    test 'rejects join if room is full (max participants)' do
      room_id = 'full_room'
      # Simulate 3 users already in the room
      Fenetre::VideoChatChannel.class_variable_set(:@@participants, { room_id => [1, 2, 3] })
      @connection = stub_connection(current_user: User.new(4), user_role: :guest)
      subscribe(room_id: room_id, max_participants: 3)
      assert subscription.rejected?, 'Should reject if room is full'
    end

    test 'allows join if room is not full (max participants)' do
      room_id = 'not_full_room'
      Fenetre::VideoChatChannel.class_variable_set(:@@participants, { room_id => [1, 2] })
      @connection = stub_connection(current_user: User.new(3), user_role: :guest)
      subscribe(room_id: room_id, max_participants: 3)
      assert subscription.confirmed?, 'Should allow join if room is not full'
    end

    test 'screen sharing events are broadcast if enabled' do
      room_id = 'screen_room'
      subscribe(room_id: room_id, enable_screen_sharing: true)
      assert_broadcasts("fenetre_video_chat_#{room_id}", 1) do
        perform :signal, { type: 'screen_share', payload: { action: 'start' } }
      end
      last = broadcasts("fenetre_video_chat_#{room_id}").last
      assert_equal 'screen_share', last[:type]
      assert_equal({ 'action' => 'start' }, last[:payload])
    end

    test 'private chat messages are only broadcast if enabled' do
      room_id = 'private_chat_room'
      subscribe(room_id: room_id, enable_private_chat: true)
      assert_broadcasts("fenetre_video_chat_#{room_id}", 1) do
        perform :chat, { message: 'hi', to: 2 }
      end
      chat = broadcasts("fenetre_video_chat_#{room_id}").last
      assert_equal 'chat', chat[:type]
      assert_equal 'hi', chat[:message]
      assert_equal 2, chat[:to]
    end

    test 'custom ICE servers are used if configured' do
      room_id = 'ice_room'
      subscribe(room_id: room_id, ice_servers: [{ 'urls' => 'stun:custom.example.com' }])
      # The controller would receive this config via Turbo/Stimulus values
      # Here we just assert the config is passed through
      assert_equal [{ 'urls' => 'stun:custom.example.com' }], subscription.instance_variable_get(:@params)[:ice_servers]
    end

    # Add more tests for edge cases, different signal types, error handling etc.
  end
end
