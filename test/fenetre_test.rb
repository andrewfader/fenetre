# frozen_string_literal: true

require 'test_helper'

class FenetreTest < ActiveSupport::TestCase
  test 'has a version number' do
    assert_match(/\A\d+\.\d+\.\d+/, Fenetre::VERSION)
  end

  test 'configuration is available to the helper' do
    original = Fenetre.video_width
    Fenetre.configure { |config| config.video_width = 640 }
    assert_equal 640, Fenetre.video_width
  ensure
    Fenetre.video_width = original
  end
end
