# frozen_string_literal: true

class VideoController < ApplicationController
  # Simple controller for the test route
  def show
    @room_id = params[:room_id] || 'default_room'
    @user_id = session[:user_id] ||= SecureRandom.uuid
    cookies.signed[:fenetre_user_id] = @user_id
  end

  def test_helper; end

  def javascript_tests
    render layout: 'test_runner', html: ''
  end
end
