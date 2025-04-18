# frozen_string_literal: true

# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

require_relative 'dummy/config/environment'
ActiveRecord::Migrator.migrations_paths = [File.expand_path('dummy/db/migrate', __dir__)]
require 'rails/test_help'
require 'action_cable/channel/test_case' # Ensure Action Cable test case is loaded

# Filter out Minitest backtrace while allowing backtrace from other libraries
# to be shown.
Minitest.backtrace_filter = Minitest::BacktraceFilter.new

# Load fixtures from the engine
# puts "[Fenetre Test Helper] Checking for engine fixtures directory..."
engine_fixture_path = File.expand_path('fixtures', __dir__)
if ActiveSupport::TestCase.respond_to?(:fixture_paths=) && Dir.exist?(engine_fixture_path)
  # puts "[Fenetre Test Helper] Engine fixtures directory found at: #{engine_fixture_path}. Adding to fixture paths."
  ActiveSupport::TestCase.fixture_paths << engine_fixture_path
  # Explicitly load fixtures if needed, adjust based on your setup
  # ActiveSupport::TestCase.fixtures :all
else
  # puts "[Fenetre Test Helper] No engine fixtures directory found at: #{engine_fixture_path}. Default fixture loading will apply."
end

# Include Action Cable testing helpers globally if needed, or specifically in channel tests
# class ActiveSupport::TestCase
#   include ActionCable::TestHelper
# end

# Ensure Action Cable uses the test adapter
ActionCable.server.config.cable = { 'adapter' => 'test' }

# Add more helper methods to be used by all tests here...
