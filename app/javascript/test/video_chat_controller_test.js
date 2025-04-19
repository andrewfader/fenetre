import { Application } from "@hotwired/stimulus"
import VideoChatController from "../controllers/fenetre/video_chat_controller.js"

QUnit.module("Fenetre::VideoChatController", hooks => {
  let application
  let element

  hooks.beforeEach(() => {
    // Start Stimulus application before each test
    application = Application.start()
    application.register("fenetre--video-chat", VideoChatController)

    // Set up the necessary HTML fixture
    const fixture = document.getElementById("qunit-fixture")
    fixture.innerHTML = `
      <div data-controller="fenetre--video-chat"
           data-fenetre--video-chat-room-id-value="qunit-room"
           data-fenetre--video-chat-user-id-value="qunit-user"
           data-fenetre--video-chat-username-value="QUnitUser"
           data-fenetre--video-chat-signal-url-value="/cable">
        <video data-fenetre--video-chat-target="localVideo"></video>
        <div data-fenetre--video-chat-target="remoteVideos"></div>
        <div data-fenetre--video-chat-target="chatMessages"></div>
        <input type="text" data-fenetre--video-chat-target="chatInput">
        <button data-action="click->fenetre--video-chat#sendChat">Send</button>
        <button data-action="click->fenetre--video-chat#toggleVideo">Toggle Video</button>
        <button data-action="click->fenetre--video-chat#toggleAudio">Toggle Audio</button>
        <button data-action="click->fenetre--video-chat#toggleScreenShare">Share Screen</button>
      </div>
    `
    element = fixture.querySelector('[data-controller="fenetre--video-chat"]')
  });

  hooks.afterEach(() => {
    // Stop Stimulus application after each test
    application.stop()
  });

  QUnit.test("Controller connects and initializes", assert => {
    assert.ok(application.controllers.find(c => c.identifier === "fenetre--video-chat"), "Controller is connected");
    const controller = application.controllers.find(c => c.identifier === "fenetre--video-chat");

    // Check initial state based on values/targets
    assert.equal(controller.roomIdValue, "qunit-room", "Room ID value is set");
    assert.equal(controller.userIdValue, "qunit-user", "User ID value is set");
    assert.ok(controller.hasLocalVideoTarget, "Local video target exists");
    assert.ok(controller.hasRemoteVideosTarget, "Remote videos target exists");
    assert.ok(controller.hasChatMessagesTarget, "Chat messages target exists");
    assert.ok(controller.hasChatInputTarget, "Chat input target exists");
  });

  QUnit.test("toggleVideo action updates state (mocked)", assert => {
    const controller = application.controllers.find(c => c.identifier === "fenetre--video-chat");
    const videoButton = element.querySelector('button[data-action*="toggleVideo"]');

    // Mock the stream and track for testing UI logic without real media
    controller.localStream = { getTracks: () => [{ kind: 'video', enabled: true, stop: () => {} }] };
    controller.isVideoEnabled = true; // Initial state

    videoButton.click();
    assert.notOk(controller.isVideoEnabled, "isVideoEnabled should be false after click");
    // In a real test, you might check button text or class changes here

    videoButton.click();
    assert.ok(controller.isVideoEnabled, "isVideoEnabled should be true after second click");
  });

  QUnit.test("toggleAudio action updates state (mocked)", assert => {
    const controller = application.controllers.find(c => c.identifier === "fenetre--video-chat");
    const audioButton = element.querySelector('button[data-action*="toggleAudio"]');

    // Mock the stream and track
    controller.localStream = { getTracks: () => [{ kind: 'audio', enabled: true, stop: () => {} }] };
    controller.isAudioEnabled = true; // Initial state

    audioButton.click();
    assert.notOk(controller.isAudioEnabled, "isAudioEnabled should be false after click");

    audioButton.click();
    assert.ok(controller.isAudioEnabled, "isAudioEnabled should be true after second click");
  });

  // Add more tests for connect, disconnect, sendChat, ActionCable interactions (potentially mocking ActionCable)
});
