import { Application } from "@hotwired/stimulus"
import VideoChatController from "fenetre/controllers/video_chat_controller"

const tick = () => new Promise(resolve => setTimeout(resolve, 0))

QUnit.module("Video chat controller", hooks => {
  let application, element, controller
  const originalGetUserMedia = navigator.mediaDevices.getUserMedia

  hooks.beforeEach(async () => {
    element = document.createElement("div")
    element.dataset.controller = "fenetre--video-chat"
    element.setAttribute("data-fenetre--video-chat-user-id-value", "42")
    element.innerHTML = `
      <input type="hidden" value="unit-room" data-fenetre--video-chat-target="roomId">
      <div data-fenetre--video-chat-target="connectionStatus"></div>
      <video data-fenetre--video-chat-target="localVideo"></video>
      <div data-fenetre--video-chat-target="remoteVideos"></div>
      <ul data-fenetre--video-chat-target="participants"></ul>
      <div data-fenetre--video-chat-target="chatMessages"></div>
      <input data-fenetre--video-chat-target="chatInput">
      <button data-action="fenetre--video-chat#toggleVideo">Camera</button>
      <button data-action="fenetre--video-chat#toggleAudio">Mic</button>
    `
    document.getElementById("qunit-fixture").appendChild(element)
    application = Application.start(element)
    // Isolate browser capture and network setup. System tests exercise both.
    class TestController extends VideoChatController {
      async startLocalVideo() {}
      createSubscription() {}
    }
    application.register("fenetre--video-chat", TestController)
    await tick()
    controller = application.getControllerForElementAndIdentifier(element, "fenetre--video-chat")
  })

  hooks.afterEach(async () => {
    navigator.mediaDevices.getUserMedia = originalGetUserMedia
    element.remove()
    await tick()
    application.stop()
  })

  QUnit.test("Stimulus resolves values and every helper target", assert => {
    assert.ok(controller)
    assert.equal(controller.roomId, "unit-room")
    assert.equal(controller.userIdValue, "42")
    for (const name of VideoChatController.targets) assert.ok(controller.targets.has(name), name)
    assert.equal(controller.mediaConstraints().video.width.ideal, 1280)
  })

  QUnit.test("connection status reports each lifecycle state", assert => {
    for (const [state, label] of Object.entries({connecting: "Connecting...", connected: "Connected",
      disconnected: "Disconnected", reconnecting: "Reconnecting...", error: "Connection Error"})) {
      controller.updateConnectionStatus(state)
      assert.equal(controller.connectionStatusTarget.textContent, label)
      assert.ok(controller.connectionStatusTarget.classList.contains(`fenetre-status-${state}`))
    }
  })

  QUnit.test("camera and mic controls toggle tracks and aria state", assert => {
    const video = {enabled: true, stop() {}}
    const audio = {enabled: true, stop() {}}
    controller.localStream = {getVideoTracks: () => [video], getAudioTracks: () => [audio], getTracks: () => [video, audio]}
    controller.toggleVideo()
    controller.toggleAudio()
    assert.notOk(video.enabled)
    assert.notOk(audio.enabled)
    assert.equal(element.querySelector(".video-off").getAttribute("aria-pressed"), "true")
    controller.toggleVideo()
    controller.toggleAudio()
    assert.ok(video.enabled)
    assert.ok(audio.enabled)
  })

  QUnit.test("chat is trimmed, empty input ignored and self echo suppressed", assert => {
    const sent = []
    controller.subscription = {perform: (...args) => sent.push(args)}
    controller.chatInputTarget.value = " "
    controller.sendChat()
    assert.equal(sent.length, 0)
    controller.chatInputTarget.value = " hello "
    controller.sendChat()
    assert.deepEqual(sent, [["send_message", {message: "hello"}]])
    controller.handleSignalingData({type: "chat", from: 42, payload: {message: "hello"}})
    assert.equal(controller.chatMessagesTarget.children.length, 1)
    assert.equal(controller.chatMessagesTarget.textContent, "You: hello")
    assert.equal(controller.chatInputTarget.value, "")
  })

  QUnit.test("failed cable send preserves the unsent message", assert => {
    controller.subscription = {perform: () => false}
    controller.chatInputTarget.value = "retry me"
    controller.sendChat()
    assert.equal(controller.chatInputTarget.value, "retry me")
    assert.equal(controller.chatMessagesTarget.children.length, 0)
  })

  QUnit.test("messages for other users and HTML are handled safely", assert => {
    controller.handleSignalingData({type: "chat", from: 99, to: "someone-else", payload: {message: "private"}})
    assert.equal(controller.chatMessagesTarget.textContent, "")
    controller.handleSignalingData({type: "chat", from: 99, to: "42", payload: {message: "<img src=x>"}})
    assert.equal(controller.chatMessagesTarget.textContent, "99: <img src=x>")
    assert.notOk(controller.chatMessagesTarget.querySelector("img"))
  })

  QUnit.test("participants are scoped to this controller", assert => {
    const other = document.createElement("ul")
    other.id = "fenetre-participant-list"
    document.getElementById("qunit-fixture").appendChild(other)
    controller.updateParticipantList([42, 99])
    assert.equal(controller.participantsTarget.children.length, 2)
    assert.equal(other.children.length, 0)
  })

  QUnit.test("ICE candidates arriving before the peer or offer are queued", async assert => {
    const candidate = {candidate: "early"}
    await controller.handleRemoteCandidate("99", candidate)
    assert.deepEqual(controller.iceCandidateQueue["99"], [candidate])
    const received = []
    controller.peerConnections["99"] = {addIceCandidate: async value => received.push(value), close() {}}
    await controller.flushIceCandidateQueue("99")
    assert.deepEqual(received, [candidate])
    assert.deepEqual(controller.iceCandidateQueue["99"], [])
  })

  QUnit.test("capture resolving after disconnect is stopped without reopening the cable", async assert => {
    let resolve, stopped = false
    navigator.mediaDevices.getUserMedia = () => new Promise(done => { resolve = done })
    const pending = VideoChatController.prototype.startLocalVideo.call(controller)
    controller.disconnect()
    resolve({getTracks: () => [{stop: () => { stopped = true }}]})
    await pending
    assert.ok(stopped)
    assert.strictEqual(controller.localStream, null)
    assert.notOk(controller.subscription)
  })

  QUnit.test("media errors show an accessible explanation", assert => {
    controller.handleMediaError(new Error("Permission denied"))
    assert.ok(element.querySelector('[role="alert"]').textContent.includes("camera or microphone"))
    assert.equal(controller.connectionStatusTarget.textContent, "Connection Error")
  })
})
