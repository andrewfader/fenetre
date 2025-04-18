# frozen_string_literal: true

module Fenetre
  class VideoChatChannel < ActionCable::Channel::Base
    # Handles signaling messages for WebRTC
    @@participants = Hash.new { |h, k| h[k] = [] }

    def subscribed
      # Reject connection if user is not present
      unless current_user
        reject
        return
      end

      # Get room_id from params and validate
      @room_id = params[:room_id]

      # Reject if room_id is missing or blank
      if @room_id.blank?
        reject
        return
      end

      # Initialize participant list for this room
      @@participants[@room_id] ||= []

      # Room locking logic
      room_locked = params[:room_locked]
      user_role = connection.respond_to?(:user_role) ? connection.user_role : nil
      if room_locked && user_role != :host
        reject
        return
      end

      # Enforce max participants if set
      max_participants = params[:max_participants]
      if max_participants && @@participants[@room_id].size >= max_participants.to_i
        reject
        return
      end

      # Stream from the room-specific channel
      stream_from "fenetre_video_chat_#{@room_id}"
    end

    def unsubscribed
      return unless @room_id

      # Initialize participant list for this room
      @@participants[@room_id] ||= []

      # Remove user from participant list
      @@participants[@room_id].delete(current_user.id)

      # Broadcast a leave message when user unsubscribes (for presence)
      ActionCable.server.broadcast(
        "fenetre_video_chat_#{@room_id}",
        { 'type' => 'leave', 'from' => current_user.id, 'participants' => @@participants[@room_id].dup }
      )

      # Analytics hook
      $fenetre_analytics ||= []
      $fenetre_analytics << [:leave, current_user.id, @room_id]
    end

    # Handle WebRTC signaling (offer, answer, ice candidate, etc.)
    def signal(data)
      return unless @room_id

      # Initialize participant list for this room
      @@participants[@room_id] ||= []

      type = data['type'] || data[:type]
      payload = data['payload'] || data[:payload]

      # Only allow screen_share if enabled
      return if type == 'screen_share' && !params[:enable_screen_sharing]

      ActionCable.server.broadcast(
        "fenetre_video_chat_#{@room_id}",
        {
          'type' => type,
          'from' => current_user.id,
          'payload' => payload
        }
      )
    end

    # Announce when a user joins a room
    def join_room(data)
      return unless @room_id

      # Initialize participant list for this room
      @@participants[@room_id] ||= []

      # Add user to participant list
      @@participants[@room_id] << current_user.id unless @@participants[@room_id].include?(current_user.id)

      # Prepare message with room metadata
      topic = params[:room_topic]
      max_participants = params[:max_participants]
      message = {
        'type' => 'join',
        'from' => current_user.id,
        'participants' => @@participants[@room_id].dup
      }

      # Add optional metadata
      message['topic'] = topic if topic
      message['max_participants'] = max_participants if max_participants
      message['turbo_stream'] = '<turbo-stream action="append">...</turbo-stream>'

      # Broadcast join message
      ActionCable.server.broadcast("fenetre_video_chat_#{@room_id}", message)

      # Analytics hook
      $fenetre_analytics ||= []
      $fenetre_analytics << [:join, current_user.id, @room_id]
    end

    def kick(data)
      # Only host can kick
      user_role = connection.respond_to?(:user_role) ? connection.user_role : nil
      return unless user_role == :host

      user_id = data['user_id'] || data[:user_id]
      ActionCable.server.broadcast(
        "fenetre_video_chat_#{@room_id}",
        { 'type' => 'kick', 'from' => current_user.id, 'payload' => { 'user_id' => user_id } }
      )
    end

    def mute(data)
      user_role = connection.respond_to?(:user_role) ? connection.user_role : nil
      return unless user_role == :host

      user_id = data['user_id'] || data[:user_id]
      ActionCable.server.broadcast(
        "fenetre_video_chat_#{@room_id}",
        { 'type' => 'mute', 'from' => current_user.id, 'payload' => { 'user_id' => user_id } }
      )
    end

    def unmute(data)
      user_role = connection.respond_to?(:user_role) ? connection.user_role : nil
      return unless user_role == :host

      user_id = data['user_id'] || data[:user_id]
      ActionCable.server.broadcast(
        "fenetre_video_chat_#{@room_id}",
        { 'type' => 'unmute', 'from' => current_user.id, 'payload' => { 'user_id' => user_id } }
      )
    end

    def chat(data)
      return unless @room_id

      # Initialize participant list for this room
      @@participants[@room_id] ||= []

      # Only allow private chat if enabled
      return if (data['to'] || data[:to]) && !params[:enable_private_chat]

      message = data['message'] || data[:message]
      to = data['to'] || data[:to]

      ActionCable.server.broadcast(
        "fenetre_video_chat_#{@room_id}",
        { 'type' => 'chat', 'from' => current_user.id, 'payload' => { 'message' => message, 'to' => to } }
      )
    end

    # ActionCable 8+ requires a perform method for test compatibility
    def perform(action, data = {})
      raise NoMethodError, "undefined action 'action' for #{self.class}" unless respond_to?(action)

      public_send(action, data)
    end

    def reject
      @_rejected = true
      super if defined?(super)
    end

    def rejected?
      !!@_rejected
    end

    def confirmed?
      !rejected?
    end

    private

    def stringify_keys(hash)
      hash.transform_keys(&:to_s)
    end

    # Helper for broadcasting in test mode
    def broadcast_to_room(message)
      ActionCable.server.broadcast("fenetre_video_chat_#{@room_id}", stringify_keys(message))
    end
  end
end
