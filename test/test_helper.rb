# frozen_string_literal: true

# Set up SimpleCov for code coverage before loading any other code
require 'simplecov'
SimpleCov.start 'rails' do
  # Track all files in the gem, not just lib
  add_filter '/test/'
  add_filter '/config/'

  # Add specific groups for better coverage analysis
  add_group 'Channels', 'app/channels'
  add_group 'Helpers', 'app/helpers'
  add_group 'Library', 'lib'
end

# Ensure version.rb is tracked in SimpleCov
require_relative '../lib/fenetre/version'

# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

require_relative 'dummy/config/environment'
ActiveRecord::Migrator.migrations_paths = [File.expand_path('dummy/db/migrate', __dir__)]
require 'rails/test_help'
require 'action_cable/channel/test_case' # Ensure Action Cable test case is loaded
require 'capybara/rails' # Add Capybara for integration tests
require 'capybara/minitest' # Add Capybara Minitest assertions
require 'importmap-rails' # Ensure importmap-rails is loaded

# Filter out Minitest backtrace while allowing backtrace from other libraries to be shown.
Minitest.backtrace_filter = Minitest::BacktraceFilter.new

# Load fixtures from the engine
engine_fixture_path = File.expand_path('fixtures', __dir__)
ActiveSupport::TestCase.fixture_paths << engine_fixture_path if ActiveSupport::TestCase.respond_to?(:fixture_paths=) && Dir.exist?(engine_fixture_path)

# Register selenium driver for Capybara
Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.binary = '/usr/bin/chromium' if File.exist?('/usr/bin/chromium')
  options.add_argument('--headless=new')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--no-sandbox')
  options.add_argument('--window-size=1400,1400')
  options.add_argument('--use-fake-device-for-media-stream')
  options.add_argument('--use-fake-ui-for-media-stream')
  options.add_argument('--autoplay-policy=no-user-gesture-required')
  options.add_option('goog:loggingPrefs', browser: 'ALL')
  service = Selenium::WebDriver::Service.chrome(path: ENV.fetch('CHROMEDRIVER', '/usr/bin/chromedriver'))
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options, service: service)
end

# Set default javascript driver
Capybara.javascript_driver = :selenium_chrome_headless

# Include Capybara DSL in Integration Tests for JavaScript capabilities
module ActionDispatch
  class IntegrationTest
    include Capybara::DSL
    include Capybara::Minitest::Assertions

    setup do
      Capybara.current_driver = :rack_test unless is_a?(ActionDispatch::SystemTestCase)
    end

    teardown do
      Capybara.reset_sessions!
      Capybara.use_default_driver
    end
  end
end

# Ensure Action Cable uses the test adapter
ActionCable.server.config.cable = { 'adapter' => 'test' }

Capybara.default_max_wait_time = 10
Capybara.enable_aria_label = true
