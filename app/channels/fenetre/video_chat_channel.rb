# frozen_string_literal: true

module Fenetre
  class VideoChatChannel < ActionCable::Channel::Base
    SIGNAL_TYPES = %w[offer answer candidate screen_share raise_hand lower_hand].freeze

    def subscribed
      return reject unless connection.respond_to?(:current_user) && current_user
      return reject if params[:room_id].blank?

      @room_id = params[:room_id].to_s
      return reject unless Fenetre.authorize_room.call(current_user, @room_id)

      @options = Fenetre.room_options.call(current_user, @room_id).symbolize_keys
      return reject if @options[:room_locked] && user_role != :host

      @accepted = true
      stream_from room_stream
      stream_from user_stream(current_user.id)
    end

    def unsubscribed
      @accepted = false
      return unless @joined

      @joined = false
      remaining = Fenetre.presence.leave(@room_id, current_user.id)
      broadcast('type' => 'leave', 'from' => current_user.id, 'participants' => remaining)
      instrument(:leave)
    end

    def join_room(_data = {})
      return unless @accepted && !@joined

      participants = Fenetre.presence.join(@room_id, current_user.id, @options[:max_participants])
      unless participants
        @accepted = false
        stop_all_streams
        return reject
      end

      @joined = true
      message = { 'type' => 'join', 'from' => current_user.id, 'participants' => participants }
      message['topic'] = @options[:room_topic] if @options[:room_topic]
      broadcast(message)
      instrument(:join)
    end

    def signal(data)
      return unless @accepted && @joined

      type = data['type'].to_s
      return unless SIGNAL_TYPES.include?(type)
      return if type == 'screen_share' && @options[:enable_screen_sharing] == false

      message = { 'type' => type, 'from' => current_user.id, 'payload' => data['payload'] }
      deliver(message, data['to'])
    end

    def chat(data)
      return unless @accepted && @joined
      return if data['to'].present? && !@options[:enable_private_chat]

      message = data['message'].to_s.strip.each_char.take(2000).join
      return if message.empty?

      deliver({ 'type' => 'chat', 'from' => current_user.id,
                'payload' => { 'message' => message, 'to' => data['to'] } }, data['to'])
    end
    alias send_message chat

    def kick(data)
      moderate('kick', data)
    end

    def mute(data)
      moderate('mute', data)
    end

    def unmute(data)
      moderate('unmute', data)
    end

    private

    def user_role
      connection.respond_to?(:user_role) ? connection.user_role&.to_sym : nil
    end

    def room_stream
      "fenetre_video_chat_#{@room_id}"
    end

    def user_stream(user_id)
      "fenetre_user_#{[@room_id, user_id.to_s].to_json}"
    end

    def broadcast(message)
      ActionCable.server.broadcast(room_stream, message)
    end

    def deliver(message, to)
      if to.present?
        message['to'] = to
        ActionCable.server.broadcast(user_stream(to), message)
      else
        broadcast(message)
      end
    end

    def moderate(type, data)
      return unless @accepted && @joined && user_role == :host && data['user_id'].present?

      deliver({ 'type' => type, 'from' => current_user.id,
                'payload' => { 'user_id' => data['user_id'] } }, data['user_id'])
    end

    def instrument(event)
      ActiveSupport::Notifications.instrument("#{event}.fenetre", user_id: current_user.id, room_id: @room_id)
    end
  end
end
