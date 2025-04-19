require 'test_helper'
require 'capybara/rails'

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Detect if running in CI environment (common CI env vars)
  CI_ENV = ENV['CI'] || ENV['GITHUB_ACTIONS'] || ENV['GITLAB_CI'] || ENV['JENKINS_URL']
  
  # Configure Chrome for either CI or local testing
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400] do |options|
    # Add Chrome options that help tests run reliably in both environments
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--no-sandbox')
    
    # Add fake media stream for WebRTC testing
    options.add_argument('--use-fake-device-for-media-stream')
    options.add_argument('--use-fake-ui-for-media-stream')
  end
end
