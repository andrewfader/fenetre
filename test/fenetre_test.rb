# frozen_string_literal: true

require_relative 'test_helper'

class FenetreTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Fenetre::VERSION
  end

  # Add more tests here to cover the gem's functionality
  # For example:
  # def test_it_does_something_useful
  #   assert true
  # end
end
