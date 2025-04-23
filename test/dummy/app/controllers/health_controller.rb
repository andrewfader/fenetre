# frozen_string_literal: true

class HealthController < ActionController::Base
  def status
    render json: { status: 'ok', version: Fenetre::VERSION }
  end

  def human_status
    render html: '<h1>Fenetre Status</h1><p>OK</p>'.html_safe, content_type: 'text/html'
  end
end
