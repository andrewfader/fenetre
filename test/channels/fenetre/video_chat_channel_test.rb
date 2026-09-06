# frozen_string_literal: true

require 'test_helper'

module Fenetre
  class VideoChatChannelTest < ActionCable::Channel::TestCase
    User = Struct.new(:id)

    setup do
      @original_presence = Fenetre.presence
      @original_options = Fenetre.room_options
      @original_authorizer = Fenetre.authorize_room
      Fenetre.presence = Presence.new
      Fenetre.room_options = ->(_user, _room) { {} }
      Fenetre.authorize_room = ->(_user, _room) { true }
      stub_connection current_user: User.new(1), user_role: :guest
    end

    teardown do
      subscription&.unsubscribe_from_channel
      Fenetre.presence = @original_presence
      Fenetre.room_options = @original_options
      Fenetre.authorize_room = @original_authorizer
    end

    test 'authenticated user subscribes to the room and their private stream' do
      subscribe(room_id: 'room')
      assert subscription.confirmed?
      assert_has_stream 'fenetre_video_chat_room'
      assert_has_stream 'fenetre_user_["room","1"]'
    end

    test 'anonymous subscription is rejected and cleanup is safe' do
      stub_connection current_user: nil
      subscribe(room_id: 'room')
      assert subscription.rejected?
      assert_no_streams
      assert_nothing_raised { subscription.unsubscribe_from_channel }
    end

    test 'subscribing without joining cannot bypass room capacity' do
      subscribe(room_id: 'room')
      assert_no_broadcasts('fenetre_video_chat_room') { perform :chat, message: 'not joined' }
      assert_no_broadcasts('fenetre_user_["room","2"]') { perform :signal, type: 'offer', to: '2' }
    end

    test 'missing room is rejected' do
      subscribe(room_id: '')
      assert subscription.rejected?
    end

    test 'host authorization controls access' do
      Fenetre.authorize_room = ->(_user, _room) { false }
      subscribe(room_id: 'room')
      assert subscription.rejected?
      assert_no_broadcasts('fenetre_video_chat_room') { subscription.perform_action('action' => 'chat', 'message' => 'denied') }
    end

    test 'room lock comes from server policy and cannot be disabled by the client' do
      Fenetre.room_options = ->(_user, _room) { { room_locked: true } }
      subscribe(room_id: 'room', room_locked: false)
      assert subscription.rejected?
    end

    test 'host can enter a locked room' do
      stub_connection current_user: User.new(1), user_role: :host
      Fenetre.room_options = ->(_user, _room) { { room_locked: true } }
      subscribe(room_id: 'room')
      assert subscription.confirmed?
    end

    test 'join and leave publish presence once using the real Action Cable dispatcher' do
      subscribe(room_id: 'room')
      assert_broadcast_on('fenetre_video_chat_room', { type: 'join', from: 1, participants: [1] }) { perform :join_room }
      assert_no_broadcasts('fenetre_video_chat_room') { perform :join_room }
      assert_broadcast_on('fenetre_video_chat_room', { type: 'leave', from: 1, participants: [] }) { unsubscribe }
      assert_no_broadcasts('fenetre_video_chat_room') { unsubscribe }
    end

    test 'room capacity is checked atomically on join' do
      Fenetre.room_options = ->(_user, _room) { { max_participants: 1 } }
      subscribe(room_id: 'room', max_participants: 100)
      Fenetre.presence.join('room', 2)
      perform :join_room
      assert subscription.rejected?
      assert_no_streams
      assert_no_broadcasts('fenetre_video_chat_room') { subscription.perform_action('action' => 'chat', 'message' => 'denied') }
    end

    test 'directed signals go only to the recipient stream with authenticated sender' do
      subscribe(room_id: 'room')
      perform :join_room
      message = { type: 'offer', from: 1, to: '2', payload: { sdp: 'v=0', type: 'offer' } }
      assert_no_broadcasts('fenetre_video_chat_room') do
        assert_broadcast_on('fenetre_user_["room","2"]', message) do
          perform :signal, type: 'offer', from: 'spoofed', to: '2', payload: message[:payload]
        end
      end
    end

    test 'unsupported signal types cannot impersonate chat or presence' do
      subscribe(room_id: 'room')
      perform :join_room
      %w[join leave chat kick].each do |type|
        assert_no_broadcasts('fenetre_video_chat_room') { perform :signal, type: type }
      end
    end

    test 'chat is trimmed and send_message remains an alias' do
      subscribe(room_id: 'room')
      perform :join_room
      assert_broadcast_on('fenetre_video_chat_room', { type: 'chat', from: 1, payload: { message: 'hello', to: nil } }) do
        perform :send_message, message: '  hello  '
      end
      assert_no_broadcasts('fenetre_video_chat_room') { perform :chat, message: ' ' }
    end

    test 'long multibyte messages remain valid UTF-8' do
      subscribe(room_id: 'room')
      perform :join_room
      assert_broadcast_on('fenetre_video_chat_room', { type: 'chat', from: 1, payload: { message: '👋' * 2000, to: nil } }) do
        perform :chat, message: '👋' * 2100
      end
    end

    test 'private chat must be enabled by the server and is never broadcast to the room' do
      subscribe(room_id: 'room', enable_private_chat: true)
      perform :join_room
      assert_no_broadcasts('fenetre_user_["room","2"]') { perform :chat, to: '2', message: 'private' }
      Fenetre.room_options = ->(_user, _room) { { enable_private_chat: true } }
      subscribe(room_id: 'room')
      perform :join_room
      assert_no_broadcasts('fenetre_video_chat_room') do
        assert_broadcast_on('fenetre_user_["room","2"]', { type: 'chat', from: 1, to: '2', payload: { message: 'private', to: '2' } }) do
          perform :chat, to: '2', message: 'private'
        end
      end
    end

    test 'guests cannot moderate peers' do
      subscribe(room_id: 'room')
      perform :join_room
      %i[kick mute unmute].each do |action|
        assert_no_broadcasts('fenetre_user_["room","2"]') { perform action, user_id: '2' }
      end
    end

    test 'host moderation targets the intended user' do
      stub_connection current_user: User.new(1), user_role: :host
      subscribe(room_id: 'room')
      perform :join_room
      %i[kick mute unmute].each do |action|
        assert_broadcast_on('fenetre_user_["room","2"]', { type: action.to_s, from: 1, to: '2', payload: { user_id: '2' } }) do
          perform action, user_id: '2'
        end
      end
    end

    test 'presence reference counts multiple subscriptions and frees empty rooms' do
      store = Presence.new
      assert_equal [1], store.join('room', 1, 1)
      assert_equal [1], store.join('room', 1, 1)
      assert_nil store.join('room', 2, 1)
      assert_equal [1], store.leave('room', 1)
      assert_empty store.leave('room', 1)
      assert_equal [2], store.join('room', 2, 1)
    end

    test 'join and leave emit notifications without retaining a global event history' do
      events = []
      listener = ->(*args) { events << ActiveSupport::Notifications::Event.new(*args) }
      ActiveSupport::Notifications.subscribed(listener, /\A(join|leave)\.fenetre\z/) do
        subscribe(room_id: 'room')
        perform :join_room
        unsubscribe
      end
      assert_equal %w[join.fenetre leave.fenetre], events.map(&:name)
      assert_equal({ user_id: 1, room_id: 'room' }, events.first.payload)
    end
  end
end
