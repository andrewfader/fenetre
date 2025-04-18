# frozen_string_literal: true

class VideoController < ApplicationController
  # Simple controller for the test route
  def show
    # In a real app, you'd find or create a room and set @room_id
    @room_id = params[:room_id] || 'default_room'
    # You also need a way to identify the current user
    # Stubbing a user ID for simplicity in the dummy app
    @user_id = session[:user_id] ||= rand(1000..9999)
  end
end
