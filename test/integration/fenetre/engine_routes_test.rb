# frozen_string_literal: true

require 'test_helper'

class EngineRoutesTest < ActionDispatch::IntegrationTest
  test 'ActionCable is mounted at /cable and does not break route reloading' do
    get '/cable'
    assert_includes [400, 404, 101], response.status,
                    "Expected /cable to be routed to ActionCable (got \\#{response.status})"
    assert_nothing_raised { Rails.application.reload_routes! }
  end
end
