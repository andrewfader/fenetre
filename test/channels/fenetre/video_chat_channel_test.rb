# frozen_string_literal: true

require 'test_helper'

module Fenetre
  class VideoChatChannelTest < ActionCable::Channel::TestCase
    # Use Action Cable testing helpers
    # https://guides.rubyonrails.org/testing.html#testing-action-cable

    # Stub current_user for channel tests
    def connection
      # Use instance variable to allow modification in tests
      @connection ||= stub_connection(current_user: User.new(1))
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

    # Helper to get the last transmitted data
    def last_transmission
      transmissions.last
    end

    # Helper to safely get the last transmission, with error message if nil
    def last_transmission!
      last = transmissions.last
      flunk('No transmission was broadcast') if last.nil?
      last
    end

    # Helper to clear ActionCable transmissions (for Rails 8+ compatibility)
    def clear_transmissions
      transmissions.clear if respond_to?(:transmissions)
    end

    # Helper to debug channel instance state after subscribing
    def debug_channel_state
      puts '@room_id: ', subscription.instance_variable_get(:@room_id).inspect
      puts '@params: ', subscription.instance_variable_get(:@params).inspect
    end

    setup do
      # Reset class variable before each test
      Fenetre::VideoChatChannel.class_variable_set(:@@participants, Hash.new { |h, k| h[k] = [] })
      # Reset analytics mock
      $fenetre_analytics = []
      # Clear connection and subscription state
      @connection = nil
      @subscription = nil
      # Clear transmissions if Action Cable doesn't do it automatically
      clear_transmissions if respond_to?(:clear_transmissions)
    end

    # Helper to subscribe, ensuring connection and params are set correctly
    def subscribe_with_connection(params = {}, user: User.new(1), user_role: nil)
      @connection = stub_connection(current_user: user, user_role: user_role)
      # Use the channel class directly
      subscribe(params.merge(channel: 'Fenetre::VideoChatChannel'))
      @subscription = subscription # Store the subscription instance if needed later
    end

    # Helper to perform an action on the current subscription
    def perform(action, data = {})
      subscription.perform(action.to_s, data)
    end

    # Helper to unsubscribe
    def unsubscribe
      subscription.unsubscribe_from_channel
    end

    test 'subscribes and streams for a room when user is present' do
      room_id = 'test_room_123'
      subscribe_with_connection({ room_id: room_id })
      assert subscription.confirmed?
    end

    test 'rejects subscription when no user is present' do
      room_id = 'test_room_456'
      # Create connection with nil user *before* subscribing
      @connection = stub_connection(current_user: nil)
      subscribe(room_id: room_id, channel: 'Fenetre::VideoChatChannel')
      assert subscription.rejected?
    end

    test 'rejects subscription when room_id is missing' do
      subscribe_with_connection({}) # No room_id provided
      assert subscription.rejected?
    end

    test 'rejects subscription when room_id is blank' do
      subscribe_with_connection({ room_id: '' }) # Blank room_id provided
      assert subscription.rejected?
    end

    test '#signal broadcasts payload to the correct stream' do
      room_id = 'test_room_789'
      user_id = 99
      subscribe_with_connection({ room_id: room_id }, user: User.new(user_id))
      subscription.instance_variable_set(:@room_id, room_id)
      assert subscription.confirmed?
      signal_payload = { 'sdp' => 'session description' }
      signal_type = 'offer'
      expected = {
        'type' => signal_type,
        'from' => user_id,
        'payload' => signal_payload
      }
      subscription.perform(:signal, { type: signal_type, payload: signal_payload })
      assert_broadcast_on("fenetre_video_chat_#{room_id}", expected)
    end

    test '#join_room broadcasts join message' do
      room_id = 'test_room_abc'
      user_id = 101
      subscribe_with_connection({ room_id: room_id }, user: User.new(user_id))
      subscription.instance_variable_set(:@room_id, room_id)
      assert subscription.confirmed?
      subscription.perform(:join_room, {})
      expected = {
        'type' => 'join',
        'from' => user_id,
        'participants' => [user_id],
        'turbo_stream' => '<turbo-stream action="append">...</turbo-stream>'
      }
      assert_broadcast_on("fenetre_video_chat_#{room_id}", expected)
    end

    test 'unsubscribing broadcasts leave message' do
      room_id = 'test_room_def'
      user_id = 102
      subscribe_with_connection({ room_id: room_id }, user: User.new(user_id))
      subscription.instance_variable_set(:@room_id, room_id)
      assert subscription.confirmed?
      subscription.perform(:join_room, {})
      unsubscribe
      expected = {
        'type' => 'leave',
        'from' => user_id,
        'participants' => []
      }
      assert_broadcast_on("fenetre_video_chat_#{room_id}", expected)
    end

    test 'guests are rejected if room is locked' do
      room_id = 'locked_room'
      subscribe_with_connection({ room_id: room_id, room_locked: true }, user: User.new(2), user_role: :guest)
      assert subscription.rejected?, 'Guest should be rejected if room is locked'
    end

    test 'host can join locked room' do
      room_id = 'locked_room'
      subscribe_with_connection({ room_id: room_id, room_locked: true }, user: User.new(1), user_role: :host)
      assert subscription.confirmed?, 'Host should be able to join locked room'
    end

    test 'room metadata is broadcast on join' do
      room_id = 'meta_room'
      topic = 'Math Help'
      max_p = 5
      subscribe_with_connection({ room_id: room_id, room_topic: topic, max_participants: max_p }, user: User.new(3),
                                                                                                  user_role: :guest)
      subscription.instance_variable_set(:@room_id, room_id)
      assert subscription.confirmed?
      subscription.perform(:join_room, {})
      expected = {
        'type' => 'join',
        'from' => 3,
        'participants' => [3],
        'topic' => topic,
        'max_participants' => max_p,
        'turbo_stream' => '<turbo-stream action="append">...</turbo-stream>'
      }
      assert_broadcast_on("fenetre_video_chat_#{room_id}", expected)
    end

    test 'broadcasts presence when user joins and leaves' do
      room_id = 'presence_room'
      user_id = 10
      subscribe_with_connection({ room_id: room_id }, user: User.new(user_id), user_role: :guest)
      subscription.instance_variable_set(:@room_id, room_id)
      assert subscription.confirmed?
      subscription.perform(:join_room, {})
      expected_join = {
        'type' => 'join',
        'from' => user_id,
        'participants' => [user_id],
        'turbo_stream' => '<turbo-stream action="append">...</turbo-stream>'
      }
      assert_broadcast_on("fenetre_video_chat_#{room_id}", expected_join)
      unsubscribe
      expected_leave = {
        'type' => 'leave',
        'from' => user_id,
        'participants' => []
      }
      assert_broadcast_on("fenetre_video_chat_#{room_id}", expected_leave)
    end

    test 'host can kick a user from the room' do
      room_id = 'mod_room'
      host_id = 1
      kicked_user_id = 42
      subscribe_with_connection({ room_id: room_id }, user: User.new(host_id), user_role: :host)
      subscription.instance_variable_set(:@room_id, room_id)
      assert subscription.confirmed?
      subscription.perform(:kick, { user_id: kicked_user_id })
      expected = {
        'type' => 'kick',
        'from' => host_id,
        'payload' => { 'user_id' => kicked_user_id }
      }
      assert_broadcast_on("fenetre_video_chat_#{room_id}", expected)
    end

    test 'custom signaling: raise_hand' do
      room_id = 'signal_room'
      user_id = 103
      subscribe_with_connection({ room_id: room_id }, user: User.new(user_id))
      subscription.instance_variable_set(:@room_id, room_id)
      assert subscription.confirmed?
      payload = { 'reason' => 'question' }
      subscription.perform(:signal, { type: 'raise_hand', payload: payload })
      expected = {
        'type' => 'raise_hand',
        'from' => user_id,
        'payload' => payload
      }
      assert_broadcast_on("fenetre_video_chat_#{room_id}", expected)
    end

    test 'host can mute and unmute a user' do
      room_id = 'mod_room'
      host_id = 1
      muted_user_id = 42
      subscribe_with_connection({ room_id: room_id }, user: User.new(host_id), user_role: :host)
      subscription.instance_variable_set(:@room_id, room_id)
      assert subscription.confirmed?
      subscription.perform(:mute, { user_id: muted_user_id })
      expected_mute = {
        'type' => 'mute',
        'from' => host_id,
        'payload' => { 'user_id' => muted_user_id }
      }
      assert_broadcast_on("fenetre_video_chat_#{room_id}", expected_mute)
      subscription.perform(:unmute, { user_id: muted_user_id })
      expected_unmute = {
        'type' => 'unmute',
        'from' => host_id,
        'payload' => { 'user_id' => muted_user_id }
      }
      assert_broadcast_on("fenetre_video_chat_#{room_id}", expected_unmute)
    end

    test 'hand-raise queue is broadcast and updated' do
      room_id = 'queue_room'
      user_id = 5
      subscribe_with_connection({ room_id: room_id }, user: User.new(user_id))
      subscription.instance_variable_set(:@room_id, room_id)
      assert subscription.confirmed?
      subscription.perform(:signal, { type: 'raise_hand', payload: { user_id: user_id } })
      expected_raise = {
        'type' => 'raise_hand',
        'from' => user_id,
        'payload' => { 'user_id' => user_id }
      }
      assert_broadcast_on("fenetre_video_chat_#{room_id}", expected_raise)
      subscription.perform(:signal, { type: 'lower_hand', payload: { user_id: user_id } })
      expected_lower = {
        'type' => 'lower_hand',
        'from' => user_id,
        'payload' => { 'user_id' => user_id }
      }
      assert_broadcast_on("fenetre_video_chat_#{room_id}", expected_lower)
    end

    test 'turbo stream UI update is broadcast on join' do
      room_id = 'turbo_room'
      subscribe_with_connection({ room_id: room_id }, user: User.new(7), user_role: :guest)
      subscription.instance_variable_set(:@room_id, room_id)
      assert subscription.confirmed?
      subscription.perform(:join_room, {})
      expected = {
        'type' => 'join',
        'from' => 7,
        'participants' => [7],
        'turbo_stream' => '<turbo-stream action="append">...</turbo-stream>'
      }
      assert_broadcast_on("fenetre_video_chat_#{room_id}", expected)
    end

    test 'participant list is updated on join and leave' do
      room_id = 'list_room'
      user_id = 100
      subscribe_with_connection({ room_id: room_id }, user: User.new(user_id), user_role: :guest)
      subscription.instance_variable_set(:@room_id, room_id)
      assert subscription.confirmed?
      subscription.perform(:join_room, {})
      expected_join = {
        'type' => 'join',
        'from' => user_id,
        'participants' => [user_id],
        'turbo_stream' => '<turbo-stream action="append">...</turbo-stream>'
      }
      assert_broadcast_on("fenetre_video_chat_#{room_id}", expected_join)
      unsubscribe
      expected_leave = {
        'type' => 'leave',
        'from' => user_id,
        'participants' => []
      }
      assert_broadcast_on("fenetre_video_chat_#{room_id}", expected_leave)
    end

    test 'chat messages are broadcast to the room' do
      room_id = 'chat_room'
      user_id = 104
      subscribe_with_connection({ room_id: room_id }, user: User.new(user_id))
      subscription.instance_variable_set(:@room_id, room_id)
      assert subscription.confirmed?
      message_text = 'Hello world!'
      subscription.perform(:chat, { message: message_text })
      expected = {
        'type' => 'chat',
        'from' => user_id,
        'payload' => { 'message' => message_text, 'to' => nil }
      }
      assert_broadcast_on("fenetre_video_chat_#{room_id}", expected)
    end

    test 'analytics hook is called on join and leave' do
      room_id = 'analytics_room'
      user_id = 200
      subscribe_with_connection({ room_id: room_id }, user: User.new(user_id), user_role: :guest)
      subscription.instance_variable_set(:@room_id, room_id)
      assert subscription.confirmed?
      $fenetre_analytics = [] # Ensure clean state
      subscription.perform(:join_room, {})
      assert_includes $fenetre_analytics, [:join, user_id, room_id]
      unsubscribe
      assert_includes $fenetre_analytics, [:leave, user_id, room_id]
    end

    test 'rejects join if room is full (max participants)' do
      room_id = 'full_room'
      max_p = 3
      # Simulate 3 users already in the room
      Fenetre::VideoChatChannel.class_variable_set(:@@participants, { room_id => [1, 2, 3] })
      subscribe_with_connection({ room_id: room_id, max_participants: max_p }, user: User.new(4), user_role: :guest)
      # Subscription should be rejected during the `subscribed` call
      assert subscription.rejected?, 'Should reject if room is full'
    end

    test 'allows join if room is not full (max participants)' do
      room_id = 'not_full_room'
      max_p = 3
      Fenetre::VideoChatChannel.class_variable_set(:@@participants, { room_id => [1, 2] })
      subscribe_with_connection({ room_id: room_id, max_participants: max_p }, user: User.new(3), user_role: :guest)
      assert subscription.confirmed?, 'Should allow join if room is not full'
    end

    test 'screen sharing events are broadcast if enabled' do
      room_id = 'screen_room'
      user_id = 105
      subscribe_with_connection({ room_id: room_id, enable_screen_sharing: true }, user: User.new(user_id))
      subscription.instance_variable_set(:@room_id, room_id)
      assert subscription.confirmed?
      payload = { 'action' => 'start' }
      subscription.perform(:signal, { type: 'screen_share', payload: payload })
      expected = {
        'type' => 'screen_share',
        'from' => user_id,
        'payload' => payload
      }
      assert_broadcast_on("fenetre_video_chat_#{room_id}", expected)
    end

    test 'private chat messages are only broadcast if enabled' do
      room_id = 'private_chat_room'
      user_id = 106
      recipient_id = 2
      subscribe_with_connection({ room_id: room_id, enable_private_chat: true }, user: User.new(user_id))
      subscription.instance_variable_set(:@room_id, room_id)
      assert subscription.confirmed?
      message_text = 'hi'
      subscription.perform(:chat, { message: message_text, to: recipient_id })
      expected = {
        'type' => 'chat',
        'from' => user_id,
        'payload' => { 'message' => message_text, 'to' => recipient_id }
      }
      assert_broadcast_on("fenetre_video_chat_#{room_id}", expected)
    end

    test 'custom ICE servers are used if configured' do
      room_id = 'ice_room'
      ice_servers = [{ 'urls' => 'stun:custom.example.com' }]
      subscribe_with_connection({ room_id: room_id, ice_servers: ice_servers })
      subscription.instance_variable_set(:@room_id, room_id)
      assert subscription.confirmed?
      # Check if the params were correctly stored in the channel instance
      assert_equal ice_servers, subscription.instance_variable_get(:@params)[:ice_servers]
    end

    # Add more tests for edge cases, different signal types, error handling etc.
  end
end
