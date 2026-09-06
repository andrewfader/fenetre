# frozen_string_literal: true

require 'application_system_test_case'

class JavascriptFunctionalitySystemTest < ApplicationSystemTestCase
  test 'media controls change real capture tracks and accessible button states' do
    visit_room('media-controls')
    assert page.evaluate_script("#{controller_script}.localStream.getVideoTracks()[0].enabled")
    click_on 'Turn off camera'
    assert_selector 'button.video-off[aria-pressed="true"]'
    refute page.evaluate_script("#{controller_script}.localStream.getVideoTracks()[0].enabled")
    click_on 'Turn on camera'
    assert page.evaluate_script("#{controller_script}.localStream.getVideoTracks()[0].enabled")
    click_on 'Mute microphone'
    refute page.evaluate_script("#{controller_script}.localStream.getAudioTracks()[0].enabled")
    click_on 'Unmute microphone'
    assert page.evaluate_script("#{controller_script}.localStream.getAudioTracks()[0].enabled")
  end

  test 'chat sends with enter and renders exactly once without interpreting HTML' do
    visit_room('chat-controls')
    input = find('[data-fenetre--video-chat-target="chatInput"]')
    input.fill_in with: '<img src=x onerror=alert(1)> hello'
    input.send_keys :enter
    assert_selector '.fenetre-chat-message', text: 'You: <img src=x onerror=alert(1)> hello', count: 1
    assert_equal '', input.value
    assert_no_selector '.fenetre-chat-message img'
  end

  test 'screen sharing replaces and restores the actual media track' do
    visit_room('screen-controls')
    # Only substitute the browser picker, using a real MediaStreamTrack.
    page.execute_script(<<~JS)
      window.cameraTrack = #{controller_script}.localStream.getVideoTracks()[0];
      navigator.mediaDevices.getDisplayMedia = async () => {
        const canvas = document.createElement('canvas');
        canvas.width = 640; canvas.height = 480;
        canvas.getContext('2d').fillRect(0, 0, 640, 480);
        window.displayStream = canvas.captureStream(15);
        return window.displayStream;
      };
    JS
    click_on 'Share screen'
    assert_selector 'button.screen-sharing', text: 'Stop Sharing'
    assert page.evaluate_script("#{controller_script}.localStream.getVideoTracks()[0] === window.displayStream.getVideoTracks()[0]")
    click_on 'Stop screen sharing'
    assert_selector 'button', text: 'Share Screen'
    assert page.evaluate_script("#{controller_script}.localStream.getVideoTracks()[0] === window.cameraTrack")
    assert_equal 'ended', page.evaluate_script('window.displayStream.getVideoTracks()[0].readyState')
  end

  test 'disconnect closes the cable consumer and stops camera and microphone' do
    visit_room('cleanup')
    page.execute_script("window.savedTracks = #{controller_script}.localStream.getTracks(); window.savedController = #{controller_script}; document.querySelector('[data-controller]').remove()")
    wait_for_script('window.savedTracks.every(track => track.readyState === "ended")')
    assert_nil page.evaluate_script('window.savedController._consumer')
    assert_nil page.evaluate_script('window.savedController.subscription')
  end
end
