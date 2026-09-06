# frozen_string_literal: true

require 'application_system_test_case'

class ImportmapSpecifierSystemTest < ApplicationSystemTestCase
  test 'all public modules import and register the working controller' do
    visit_room('import-check')
    result = page.evaluate_async_script(<<~JS)
      const done = arguments[0];
      Promise.all(['application', '@hotwired/stimulus', '@rails/actioncable', 'fenetre',
        'fenetre/application', 'fenetre/controllers', 'controllers/fenetre/video_chat_controller']
        .map(name => import(name))).then(modules => done({loaded: modules.length}),
          error => done({error: error.message}));
    JS
    assert_equal({ 'loaded' => 7 }, result)
    assert page.evaluate_script("#{controller_script}.localStream.active")
  end
end
