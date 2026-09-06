# frozen_string_literal: true

require 'application_system_test_case'

class JavascriptTest < ApplicationSystemTestCase
  test 'all JavaScript unit tests complete successfully' do
    visit '/javascript_tests'
    assert_selector 'body[data-qunit-complete="true"]', wait: 30
    result = page.evaluate_script('window.qunitResult')
    failures = page.evaluate_script('window.qunitFailures')
    assert_operator result.fetch('total'), :>, 0
    assert_equal 0, result.fetch('failed'), failures.inspect
    puts "QUnit: #{result['total']} assertions, #{result['failed']} failures"
  end
end
