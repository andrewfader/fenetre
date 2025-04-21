# frozen_string_literal: true

require_relative 'test_helper'
require 'ostruct'

class FenetreTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Fenetre::VERSION
  end
end

class FenetreEngineTest < ActiveSupport::TestCase
  # Setup and teardown to ensure we don't affect other tests
  def setup
    @original_log_warning = Fenetre::Engine.method(:log_warning)
  end
  
  def teardown
    if @original_log_warning
      Fenetre::Engine.singleton_class.send(:define_method, :log_warning, @original_log_warning)
    end
  end

  # Simulate a Rails app with no importmap-rails
  class DummyAppNoImportmap
    def config
      @config ||= OpenStruct.new.tap do |c|
        # Make sure respond_to?(:importmap) returns false
        def c.respond_to?(method_name, *)
          return false if method_name == :importmap
          super
        end
      end
    end

    def routes
      @routes ||= OpenStruct.new(routes: [], append: ->(&block) {})
    end
  end

  test 'logs warning if importmap is not present' do
    app = DummyAppNoImportmap.new
    
    # Track if log_warning was called
    warning_msg = nil
    Fenetre::Engine.singleton_class.send(:define_method, :log_warning) do |msg|
      warning_msg = msg
    end
    
    # Find and directly invoke the importmap initializer
    importmap_initializer = Fenetre::Engine.initializers.find { |i| i.name == 'fenetre.importmap' }
    assert_not_nil importmap_initializer, "Could not find fenetre.importmap initializer"
    
    # Run the initializer manually
    importmap_initializer.run(app)
    
    # Check if the warning was triggered
    assert_not_nil warning_msg, "log_warning was not called"
    assert_match(/requires importmap-rails/, warning_msg, "Warning message didn't match expected content")
  end

  # Simulate a Rails app with no Propshaft or Sprockets
  class DummyAppNoAssets
    def config
      @config ||= OpenStruct.new.tap do |c|
        # Make respond_to? return false for any method
        def c.respond_to?(*)
          false
        end
        # Explicitly prevent propshaft from being defined
        def c.method_missing(method_name, *args)
          return nil if method_name == :propshaft
          super
        end
      end
    end
  end

  test 'logs warning if neither asset pipeline is detected' do
    app = DummyAppNoAssets.new
    
    # Track if log_warning was called
    warning_msg = nil
    Fenetre::Engine.singleton_class.send(:define_method, :log_warning) do |msg|
      warning_msg = msg
    end
    
    # Find and directly invoke the assets initializer
    assets_initializer = Fenetre::Engine.initializers.find { |i| i.name == 'fenetre.assets' }
    assert_not_nil assets_initializer, "Could not find fenetre.assets initializer"
    
    # Run the initializer manually
    assets_initializer.run(app)
    
    # Check if the warning was triggered
    assert_not_nil warning_msg, "log_warning was not called"
    assert_match(/could not detect Propshaft/, warning_msg, "Warning message didn't match expected content")
  end
end
