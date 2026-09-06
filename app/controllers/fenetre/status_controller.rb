# frozen_string_literal: true

module Fenetre
  class StatusController < ActionController::Base
    def show
      render json: { status: 'ok', time: Time.now.utc.iso8601, version: Fenetre::VERSION }
    end

    def human
      render html: helpers.content_tag(:h1, "Fenetre Status: ok (#{Fenetre::VERSION})")
    end
  end
end
