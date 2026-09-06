# frozen_string_literal: true

module Fenetre
  # The default store is process-local. Multi-process deployments can supply
  # a shared store with atomic join(room, user, limit) and leave(room, user).
  class Presence
    def initialize
      @rooms = {}
      @mutex = Mutex.new
    end

    def join(room, user, limit = nil)
      @mutex.synchronize do
        users = @rooms[room] ||= {}
        return if limit && users.size >= limit.to_i && !users.key?(user)

        users[user] = users.fetch(user, 0) + 1
        users.keys
      end
    end

    def leave(room, user)
      @mutex.synchronize do
        users = @rooms[room] || {}
        if users.key?(user)
          users[user] -= 1
          users.delete(user) if users[user].zero?
        end
        @rooms.delete(room) if users.empty?
        users.keys
      end
    end
  end
end
