# frozen_string_literal: true

require 'application_system_test_case'

class VideoChatSystemTest < ApplicationSystemTestCase
  test 'two browsers exchange live video audio and chat then clean up a departed peer' do
    visit_room('two-browser-proof')
    first_id = page.evaluate_script("#{controller_script}.userIdValue")

    using_session(:second_participant) do
      visit_room('two-browser-proof')
      assert_selector '.fenetre-participant-list li', count: 2
      assert_remote_media
      find('[data-fenetre--video-chat-target="chatInput"]').fill_in with: 'Hello from the second browser'
      click_on 'Send'
      assert_selector '.fenetre-chat-message', text: 'You: Hello from the second browser', count: 1
    end

    assert_selector '.fenetre-participant-list li', count: 2
    assert_remote_media
    assert_selector '.fenetre-chat-message', text: 'Hello from the second browser', count: 1
    find('[data-fenetre--video-chat-target="chatInput"]').fill_in with: 'Reply from the first browser'
    click_on 'Send'

    using_session(:second_participant) do
      assert_selector '.fenetre-chat-message', text: "#{first_id}: Reply from the first browser", count: 1
      visit '/up'
    end

    assert_no_selector '.fenetre-remote-video-container'
    assert_selector '.fenetre-participant-list li', count: 1
    assert_empty page.evaluate_script("Object.keys(#{controller_script}.peerConnections)")
  end

  test 'users in different rooms do not receive each others chat or media' do
    visit_room('isolated-first')
    using_session(:other_room) do
      visit_room('isolated-second')
      find('[data-fenetre--video-chat-target="chatInput"]').fill_in with: 'A different room'
      click_on 'Send'
      assert_selector '.fenetre-chat-message', text: 'A different room'
    end
    assert_no_selector '.fenetre-chat-message'
    assert_no_selector '.fenetre-remote-video-container'
    assert_selector '.fenetre-participant-list li', count: 1
  end

  private

  def assert_remote_media
    assert_selector '.fenetre-peer-connected', text: 'Connected'
    wait_for_script(<<~JS)
      (() => {
        const video = document.querySelector('.fenetre-remote-video-container video');
        return video && video.videoWidth > 0 && video.currentTime > 0 &&
          video.srcObject.getAudioTracks().some(track => track.readyState === 'live') &&
          video.srcObject.getVideoTracks().some(track => track.readyState === 'live');
      })()
    JS
    stats = page.evaluate_async_script(<<~JS)
      const done = arguments[0];
      const pc = Object.values(#{controller_script}.peerConnections)[0];
      pc.getStats().then(report => done(Array.from(report.values())
        .filter(stat => stat.type === 'inbound-rtp')
        .map(stat => ({kind: stat.kind, bytes: stat.bytesReceived}))), error => done({error: error.message}));
    JS
    %w[audio video].each do |kind|
      assert stats.any? { |stat| stat['kind'] == kind && stat['bytes'].positive? }, "Expected received #{kind} RTP packets: #{stats.inspect}"
    end
  end
end
