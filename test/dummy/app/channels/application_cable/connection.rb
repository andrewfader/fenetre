# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      id = cookies.signed[:fenetre_user_id]
      reject_unauthorized_connection unless id
      self.current_user = Struct.new(:id).new(id)
    end
  end
end
