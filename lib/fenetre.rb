# frozen_string_literal: true

require_relative 'fenetre/version'
require_relative 'fenetre/engine'

module Fenetre
  # Default ICE servers. Override in an initializer for production TURN:
  #
  #   Fenetre.configure do |c|
  #     c.ice_servers = [
  #       { urls: 'stun:stun.l.google.com:19302' },
  #       { urls: 'turn:turn.example.com:3478', username: 'u', credential: 'p' }
  #     ]
  #   end
  #
  # Without TURN, many corporate NATs and mobile networks will never connect —
  # Zoom/Skype/Jitsi always ship TURN.
  mattr_accessor :ice_servers
  self.ice_servers = [
    { urls: 'stun:stun.l.google.com:19302' },
    { urls: 'stun:stun1.l.google.com:19302' }
  ].freeze

  mattr_accessor :max_video_bitrate
  self.max_video_bitrate = 2_500_000

  mattr_accessor :max_audio_bitrate
  self.max_audio_bitrate = 128_000

  mattr_accessor :video_width
  self.video_width = 1280

  mattr_accessor :video_height
  self.video_height = 720

  mattr_accessor :frame_rate
  self.frame_rate = 30

  def self.configure
    yield self
  end
end
