# frozen_string_literal: true

module Fenetre
  class VideoChatChannel < ActionCable::Channel::Base
    # Handles signaling messages for WebRTC
    @@participants = Hash.new { |h, k| h[k] = [] }

    def subscribed
      return reject unless current_user

      @room_id = params[:room_id]
      return reject if @room_id.blank?

      init_participants(@room_id)
      return reject if params[:room_locked] && user_role != :host
      return reject if params[:max_participants] && participants(@room_id).size >= params[:max_participants].to_i

      stream_from room_stream(@room_id)
    end

    def unsubscribed
      return unless @room_id

      remove_participant(@room_id, current_user.id)
      broadcast_leave(@room_id, current_user.id)
      log_analytics(:leave, current_user.id, @room_id)
    end

    def signal(data)
      return unless @room_id

      init_participants(@room_id)
      type = data['type'] || data[:type]
      payload = data['payload'] || data[:payload]
      return if type == 'screen_share' && !params[:enable_screen_sharing]

      broadcast_signal(@room_id, type, current_user.id, payload)
    end

    def join_room(_data)
      return unless @room_id

      add_participant(@room_id, current_user.id)
      message = {
        'type' => 'join',
        'from' => current_user.id,
        'participants' => participants(@room_id).dup
      }
      message['topic'] = params[:room_topic] if params[:room_topic]
      message['max_participants'] = params[:max_participants] if params[:max_participants]
      message['turbo_stream'] = '<turbo-stream action="append">...</turbo-stream>'
      ActionCable.server.broadcast(room_stream(@room_id), message)
      log_analytics(:join, current_user.id, @room_id)
    end

    def kick(data)
      return unless user_role == :host

      user_id = data['user_id'] || data[:user_id]
      ActionCable.server.broadcast(room_stream(@room_id),
                                   { 'type' => 'kick', 'from' => current_user.id,
                                     'payload' => { 'user_id' => user_id } })
    end

    def mute(data)
      return unless user_role == :host

      user_id = data['user_id'] || data[:user_id]
      ActionCable.server.broadcast(room_stream(@room_id),
                                   { 'type' => 'mute', 'from' => current_user.id,
                                     'payload' => { 'user_id' => user_id } })
    end

    def unmute(data)
      return unless user_role == :host

      user_id = data['user_id'] || data[:user_id]
      ActionCable.server.broadcast(room_stream(@room_id),
                                   { 'type' => 'unmute', 'from' => current_user.id,
                                     'payload' => { 'user_id' => user_id } })
    end

    def chat(data)
      return unless @room_id

      init_participants(@room_id)
      return if (data['to'] || data[:to]) && !params[:enable_private_chat]

      message = data['message'] || data[:message]
      to = data['to'] || data[:to]
      ActionCable.server.broadcast(room_stream(@room_id),
                                   { 'type' => 'chat', 'from' => current_user.id,
                                     'payload' => { 'message' => message, 'to' => to } })
    end

    def perform(action, data = {})
      raise NoMethodError, "undefined action '#{action}' for #{self.class}" unless respond_to?(action)

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

    def user_role
      connection.respond_to?(:user_role) ? connection.user_role : nil
    end

    def room_stream(room_id)
      "fenetre_video_chat_#{room_id}"
    end

    def init_participants(room_id)
      @@participants[room_id] ||= []
    end

    def participants(room_id)
      @@participants[room_id] ||= []
    end

    def add_participant(room_id, user_id)
      @@participants[room_id] << user_id unless @@participants[room_id].include?(user_id)
    end

    def remove_participant(room_id, user_id)
      @@participants[room_id]&.delete(user_id)
    end

    def broadcast_leave(room_id, user_id)
      ActionCable.server.broadcast(room_stream(room_id),
                                   { 'type' => 'leave', 'from' => user_id,
                                     'participants' => participants(room_id).dup })
    end

    def broadcast_signal(room_id, type, from, payload)
      ActionCable.server.broadcast(room_stream(room_id), { 'type' => type, 'from' => from, 'payload' => payload })
    end

    def log_analytics(event, user_id, room_id)
      $fenetre_analytics ||= []
      $fenetre_analytics << [event, user_id, room_id]
    end

    def stringify_keys(hash)
      hash.transform_keys(&:to_s)
    end

    def broadcast_to_room(message)
      ActionCable.server.broadcast(room_stream(@room_id), stringify_keys(message))
    end
  end
end
