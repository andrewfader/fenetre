# test/test_helper.rb (Modified)

# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

# --- Load Rails environment and test helpers ---
# Load the dummy app's environment first
require_relative "../test/dummy/config/environment"
# Then load rails test help which defines ActiveSupport::TestCase etc.
# This needs to happen before we try to modify those classes.
require "rails/test_help"
# --- End Loading ---

# Load other test dependencies
require "minitest/autorun"

# Filter out Minitest backtrace while allowing backtrace from other libraries
# to be shown.
Minitest.backtrace_filter = Minitest::BacktraceFilter.new


# --- Configure Fixtures Inside Test Classes ---
# Define the path to your engine's fixtures
engine_fixture_path = Fenetre::Engine.root.join("test", "fixtures")

# Check if the custom fixture path exists before attempting to set it
if File.directory?(engine_fixture_path)
  puts "[Fenetre Test Helper] Engine fixtures found at: #{engine_fixture_path}. Configuring path."

  # Configure ActiveSupport::TestCase (Base for unit/model/controller tests)
  class ActiveSupport::TestCase
    # Set the fixture path *for this class and subclasses*
    # Use self.fixture_path= assignment INSIDE the class definition
    self.fixture_path = engine_fixture_path

    # Load all fixtures found in the specified path for tests inheriting from this
    fixtures :all
  end

  # Configure ActionDispatch::IntegrationTest (Base for integration tests)
  # It often inherits from ActiveSupport::TestCase, but explicitly setting
  # the path can prevent issues if the inheritance changes or is complex.
  # Setting it again is generally safe.
  class ActionDispatch::IntegrationTest
    self.fixture_path = engine_fixture_path
    # fixtures :all is typically inherited from ActiveSupport::TestCase,
    # so usually not needed here unless you want different fixtures for integration tests.
  end

else
   puts "[Fenetre Test Helper] No engine fixtures directory found at: #{engine_fixture_path}. Default fixture loading will apply (usually from test/dummy/test/fixtures)."
   # If the engine fixture path doesn't exist, still ensure fixtures are loaded
   # by default (usually from the dummy app's fixture path: test/dummy/test/fixtures)
   class ActiveSupport::TestCase
     fixtures :all
   end
end
