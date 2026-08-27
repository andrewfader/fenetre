import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="fenetre--video-chat"
// Quality bar: Zoom / Skype / Jitsi — HD capture, AEC/NS, TURN-ready ICE,
// targeted signaling, perfect negotiation, ICE restart, bitrate caps.
export default class extends Controller {
  static targets = [
    "localVideo",
    "remoteVideos",
    "roomId",
    "chatInput",
    "chatMessages",
    "connectionStatus",
  ]
  static values = {
    userId: String,
    iceServers: { type: Array, default: [{ urls: "stun:stun.l.google.com:19302" }] },
    maxVideoBitrate: { type: Number, default: 2_500_000 },
    maxAudioBitrate: { type: Number, default: 128_000 },
    videoWidth: { type: Number, default: 1280 },
    videoHeight: { type: Number, default: 720 },
    frameRate: { type: Number, default: 30 },
  }

  connect() {
    this.peerConnections = {}
    this.makingOffer = {}
    this.ignoreOffer = {}
    this.iceCandidateQueue = {}
    this.iceRestartTimers = {}
    this.localStream = null
    this.screenStream = null
    this.isScreenSharing = false
    this.savedVideoTrack = null
    this._cableConnected = this.handleActionCableConnected.bind(this)
    this._cableDisconnected = this.handleActionCableDisconnected.bind(this)
    this._screenShareChanged = this.handleScreenSharingChange.bind(this)

    if (!this.hasConnectionStatusTarget || !this.hasRoomIdTarget) {
      console.error("Fenetre: required targets missing (connectionStatus / roomId).")
      return
    }

    this.roomId = this.roomIdTarget.value
    if (!this.roomId) {
      console.error("Fenetre: Room ID value is missing!")
      return
    }

    // Perfect negotiation: the peer with the lexicographically greater id is polite.
    this.isPolite = (peerId) => String(this.userIdValue) > String(peerId)

    this.updateConnectionStatus("connecting")
    this.setupConnectionEventListeners()

    this.startLocalVideo()
      .then(() => this.createSubscription())
      .catch((error) => this.handleMediaError(error))
  }

  setupConnectionEventListeners() {
    document.addEventListener("cable-ready:connected", this._cableConnected)
    document.addEventListener("cable-ready:disconnected", this._cableDisconnected)
    document.addEventListener("screen-sharing-changed", this._screenShareChanged)
  }

  handleActionCableConnected() {
    this.updateConnectionStatus("connected")
  }

  handleActionCableDisconnected() {
    this.updateConnectionStatus("disconnected")
  }

  handleScreenSharingChange(event) {
    const button = this.element.querySelector(
      'button[data-action*="fenetre--video-chat#toggleScreenShare"]'
    )
    if (!button) return
    if (event.detail?.status === "started") {
      button.classList.add("screen-sharing")
      button.textContent = "Stop Sharing"
    } else if (event.detail?.status === "stopped") {
      button.classList.remove("screen-sharing")
      button.textContent = "Share Screen"
    }
  }

  disconnect() {
    document.removeEventListener("cable-ready:connected", this._cableConnected)
    document.removeEventListener("cable-ready:disconnected", this._cableDisconnected)
    document.removeEventListener("screen-sharing-changed", this._screenShareChanged)

    Object.keys(this.iceRestartTimers || {}).forEach((id) => {
      clearTimeout(this.iceRestartTimers[id])
    })
    this.iceRestartTimers = {}

    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
    if (this.localStream) {
      this.localStream.getTracks().forEach((t) => t.stop())
      this.localStream = null
    }
    if (this.screenStream) {
      this.screenStream.getTracks().forEach((t) => t.stop())
      this.screenStream = null
    }
    Object.values(this.peerConnections).forEach((pc) => pc.close())
    this.peerConnections = {}
    if (this.hasRemoteVideosTarget) {
      this.remoteVideosTarget.innerHTML = ""
    }
    this.updateConnectionStatus("disconnected")
  }

  updateConnectionStatus(status) {
    if (!this.hasConnectionStatusTarget) return
    const el = this.connectionStatusTarget
    el.classList.remove(
      "fenetre-status-connecting",
      "fenetre-status-connected",
      "fenetre-status-disconnected",
      "fenetre-status-reconnecting",
      "fenetre-status-error"
    )
    const labels = {
      connecting: ["fenetre-status-connecting", "Connecting..."],
      connected: ["fenetre-status-connected", "Connected"],
      disconnected: ["fenetre-status-disconnected", "Disconnected"],
      reconnecting: ["fenetre-status-reconnecting", "Reconnecting..."],
      error: ["fenetre-status-error", "Connection Error"],
    }
    const [cls, text] = labels[status] || labels.error
    el.classList.add(cls)
    el.textContent = text
  }

  mediaConstraints() {
    return {
      audio: {
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true,
        channelCount: 1,
      },
      video: {
        width: { ideal: this.videoWidthValue, max: 1920 },
        height: { ideal: this.videoHeightValue, max: 1080 },
        frameRate: { ideal: this.frameRateValue, max: 60 },
        facingMode: "user",
      },
    }
  }

  async startLocalVideo() {
    this.localStream = await navigator.mediaDevices.getUserMedia(this.mediaConstraints())
    if (this.hasLocalVideoTarget) {
      this.localVideoTarget.srcObject = this.localStream
      this.localVideoTarget.muted = true
      this.localVideoTarget.playsInline = true
      try {
        await this.localVideoTarget.play()
      } catch (_) {
        /* autoplay policies may block; muted should allow it */
      }
    }
  }

  handleMediaError(error) {
    console.error("Media access error:", error)
    this.updateConnectionStatus("error")
    const errorMessage = document.createElement("div")
    errorMessage.className = "fenetre-media-error"
    errorMessage.setAttribute("role", "alert")
    errorMessage.textContent =
      "Could not access camera or microphone. Check permissions and that no other app is using them."
    this.element.insertBefore(errorMessage, this.element.firstChild)
  }

  createSubscription() {
    if (!window.App?.cable && !window.ActionCable) {
      console.error("ActionCable not available.")
      this.updateConnectionStatus("error")
      return
    }

    const consumer =
      window.App?.cable ||
      this._consumer ||
      (this._consumer = window.ActionCable.createConsumer())

    this.subscription = consumer.subscriptions.create(
      { channel: "Fenetre::VideoChatChannel", room_id: this.roomId },
      {
        connected: () => {
          this.updateConnectionStatus("connected")
          this.announceJoin()
        },
        disconnected: () => {
          this.updateConnectionStatus("reconnecting")
        },
        rejected: () => {
          this.updateConnectionStatus("error")
        },
        received: (data) => this.handleSignalingData(data),
      }
    )
  }

  announceJoin() {
    this.subscription?.perform("join_room", {})
  }

  handleSignalingData(data) {
    if (!data || typeof data !== "object") return

    if (data.turbo_stream) {
      this.applyTurboStream(data.turbo_stream)
    }

    if (data.type === "join") this.onJoin?.(data)
    else if (data.type === "leave") this.onLeave?.(data)
    else if (data.type === "chat") this.onChat?.(data)
    else if (data.type === "mute" || data.type === "unmute") this.onModeration?.(data)
    else if (data.type === "raise_hand" || data.type === "lower_hand") this.onHandRaise?.(data)

    const from = data.from != null ? String(data.from) : null
    const to = data.to != null ? String(data.to) : null
    const selfId = String(this.userIdValue)

    if (from === selfId) return
    // Targeted signals: ignore if addressed to someone else
    if (to && to !== selfId) return

    switch (data.type) {
      case "join":
        // Existing peers offer to the joiner (mesh).
        this.createPeerConnection(from, true)
        break
      case "offer":
        this.handleOffer(from, data.payload)
        break
      case "answer":
        this.handleAnswer(from, data.payload)
        break
      case "candidate":
        this.handleRemoteCandidate(from, data.payload)
        break
      case "leave":
        this.removePeerConnection(from)
        break
      case "chat":
        // already handled in onChat
        break
      default:
        break
    }
  }

  applyTurboStream(turboStreamHtml) {
    const template = document.createElement("template")
    template.innerHTML = String(turboStreamHtml).trim()
    const stream = template.content.firstElementChild
    if (stream && stream.tagName === "TURBO-STREAM") {
      if (window.Turbo?.renderStreamMessage) {
        window.Turbo.renderStreamMessage(turboStreamHtml)
      } else {
        document.body.appendChild(stream)
      }
    }
  }

  onJoin(data) {
    if (data.participants) this.updateParticipantList(data.participants)
  }

  onLeave(data) {
    if (data.participants) this.updateParticipantList(data.participants)
  }

  onChat(data) {
    const message = data.payload?.message ?? data.message
    if (!message) return
    this.appendChatMessage({ from: data.from, message })
  }

  updateParticipantList(participants) {
    const list = document.getElementById("fenetre-participant-list")
    if (!list) return
    list.innerHTML = ""
    participants.forEach((id) => {
      const li = document.createElement("li")
      li.textContent = `User ${id}`
      list.appendChild(li)
    })
  }

  appendChatMessage(data) {
    if (!this.hasChatMessagesTarget) return
    const messageEl = document.createElement("div")
    messageEl.className = "fenetre-chat-message"
    messageEl.textContent = `${data.from}: ${data.message}`
    this.chatMessagesTarget.appendChild(messageEl)
    this.chatMessagesTarget.scrollTop = this.chatMessagesTarget.scrollHeight
  }

  sendChat(event) {
    event?.preventDefault?.()
    if (!this.hasChatInputTarget) return
    const message = this.chatInputTarget.value.trim()
    if (!message || !this.subscription) return

    this.subscription.perform("send_message", { message })
    this.chatInputTarget.value = ""
    this.appendChatMessage({ from: "You", message })
  }

  toggleVideo() {
    const track = this.localStream?.getVideoTracks()?.[0]
    if (!track) return
    track.enabled = !track.enabled
    const button = this.element.querySelector(
      'button[data-action*="fenetre--video-chat#toggleVideo"]'
    )
    if (button) {
      button.classList.toggle("video-off", !track.enabled)
      button.setAttribute("aria-label", track.enabled ? "Turn off camera" : "Turn on camera")
      button.setAttribute("aria-pressed", String(!track.enabled))
    }
  }

  toggleAudio() {
    const track = this.localStream?.getAudioTracks()?.[0]
    if (!track) return
    track.enabled = !track.enabled
    const button = this.element.querySelector(
      'button[data-action*="fenetre--video-chat#toggleAudio"]'
    )
    if (button) {
      button.classList.toggle("audio-off", !track.enabled)
      button.setAttribute("aria-label", track.enabled ? "Mute microphone" : "Unmute microphone")
      button.setAttribute("aria-pressed", String(!track.enabled))
    }
  }

  toggleScreenShare() {
    if (this.isScreenSharing) this.stopScreenSharing()
    else this.startScreenSharing()
  }

  async startScreenSharing() {
    try {
      this.screenStream = await navigator.mediaDevices.getDisplayMedia({
        video: {
          cursor: "always",
          width: { ideal: 1920 },
          height: { ideal: 1080 },
          frameRate: { ideal: 30, max: 60 },
        },
        audio: false,
      })

      this.savedVideoTrack = this.localStream?.getVideoTracks()?.[0] || null
      const screenTrack = this.screenStream.getVideoTracks()[0]

      await this.replaceVideoTrack(screenTrack, 4_000_000)

      if (this.savedVideoTrack && this.localStream) {
        this.localStream.removeTrack(this.savedVideoTrack)
        this.localStream.addTrack(screenTrack)
        if (this.hasLocalVideoTarget) this.localVideoTarget.srcObject = this.localStream
      }

      const button = this.element.querySelector(
        'button[data-action*="fenetre--video-chat#toggleScreenShare"]'
      )
      if (button) {
        button.classList.add("screen-sharing")
        button.setAttribute("aria-label", "Stop screen sharing")
        button.textContent = "Stop Sharing"
      }

      this.isScreenSharing = true
      screenTrack.onended = () => this.stopScreenSharing()
    } catch (error) {
      console.error("Error starting screen share:", error)
    }
  }

  async stopScreenSharing() {
    if (!this.isScreenSharing) return
    try {
      this.screenStream?.getTracks()?.forEach((t) => t.stop())
      this.screenStream = null

      if (this.localStream) {
        const screenTrack = this.localStream.getVideoTracks()[0]
        if (screenTrack) this.localStream.removeTrack(screenTrack)
        if (this.savedVideoTrack) {
          this.localStream.addTrack(this.savedVideoTrack)
          await this.replaceVideoTrack(this.savedVideoTrack, this.maxVideoBitrateValue)
        }
        if (this.hasLocalVideoTarget) this.localVideoTarget.srcObject = this.localStream
      }

      const button = this.element.querySelector(
        'button[data-action*="fenetre--video-chat#toggleScreenShare"]'
      )
      if (button) {
        button.classList.remove("screen-sharing")
        button.setAttribute("aria-label", "Share screen")
        button.textContent = "Share Screen"
      }

      this.isScreenSharing = false
      this.savedVideoTrack = null
    } catch (error) {
      console.error("Error stopping screen share:", error)
    }
  }

  async replaceVideoTrack(track, maxBitrate) {
    const replacements = Object.values(this.peerConnections).map(async (pc) => {
      const sender = pc.getSenders().find((s) => s.track && s.track.kind === "video")
      if (!sender) return
      await sender.replaceTrack(track)
      await this.applySenderBitrate(sender, maxBitrate)
    })
    await Promise.all(replacements)
  }

  async applySenderBitrate(sender, maxBitrate) {
    try {
      const params = sender.getParameters()
      if (!params.encodings || params.encodings.length === 0) {
        params.encodings = [{}]
      }
      params.encodings[0].maxBitrate = maxBitrate
      if (sender.track?.kind === "video") {
        params.encodings[0].maxFramerate = this.frameRateValue
      }
      await sender.setParameters(params)
    } catch (e) {
      console.warn("Fenetre: setParameters failed", e)
    }
  }

  iceConfiguration() {
    const servers =
      this.iceServersValue?.length > 0
        ? this.iceServersValue
        : [{ urls: "stun:stun.l.google.com:19302" }]
    return {
      iceServers: servers,
      iceCandidatePoolSize: 4,
      bundlePolicy: "max-bundle",
      rtcpMuxPolicy: "require",
    }
  }

  createPeerConnection(peerId, isOffering) {
    peerId = String(peerId)
    if (this.peerConnections[peerId]) {
      if (isOffering) this.makeOffer(peerId)
      return this.peerConnections[peerId]
    }

    const pc = new RTCPeerConnection(this.iceConfiguration())
    this.peerConnections[peerId] = pc
    this.iceCandidateQueue[peerId] = []
    this.makingOffer[peerId] = false
    this.ignoreOffer[peerId] = false

    if (this.localStream) {
      this.localStream.getTracks().forEach((track) => {
        const sender = pc.addTrack(track, this.localStream)
        const max =
          track.kind === "audio" ? this.maxAudioBitrateValue : this.maxVideoBitrateValue
        this.applySenderBitrate(sender, max)
      })
    }

    pc.ontrack = (event) => {
      const stream = event.streams[0] || new MediaStream([event.track])
      this.addRemoteVideo(peerId, stream)
    }

    pc.onicecandidate = (event) => {
      if (event.candidate) {
        this.sendSignal(peerId, "candidate", event.candidate.toJSON?.() || event.candidate)
      }
    }

    pc.oniceconnectionstatechange = () => {
      this.updatePeerConnectionState(peerId, pc)
      const state = pc.iceConnectionState
      if (state === "failed") {
        this.restartIce(peerId)
      } else if (state === "disconnected") {
        clearTimeout(this.iceRestartTimers[peerId])
        this.iceRestartTimers[peerId] = setTimeout(() => {
          if (
            this.peerConnections[peerId] &&
            ["disconnected", "failed"].includes(this.peerConnections[peerId].iceConnectionState)
          ) {
            this.restartIce(peerId)
          }
        }, 2000)
      } else if (state === "connected" || state === "completed") {
        clearTimeout(this.iceRestartTimers[peerId])
      } else if (state === "closed") {
        this.removePeerConnection(peerId)
      }
    }

    pc.onconnectionstatechange = () => {
      this.updatePeerConnectionState(peerId, pc)
      if (pc.connectionState === "failed") {
        this.restartIce(peerId)
      } else if (pc.connectionState === "closed") {
        this.removePeerConnection(peerId)
      }
    }

    pc.onnegotiationneeded = async () => {
      try {
        await this.makeOffer(peerId)
      } catch (e) {
        console.error("negotiationneeded failed", e)
      }
    }

    if (isOffering) {
      this.makeOffer(peerId)
    }

    return pc
  }

  async makeOffer(peerId) {
    const pc = this.peerConnections[peerId]
    if (!pc) return
    try {
      this.makingOffer[peerId] = true
      const offer = await pc.createOffer({ iceRestart: false })
      if (pc.signalingState !== "stable") return
      await pc.setLocalDescription(offer)
      this.sendSignal(peerId, "offer", pc.localDescription)
    } catch (e) {
      console.error("Error creating offer:", e)
    } finally {
      this.makingOffer[peerId] = false
    }
  }

  async restartIce(peerId) {
    const pc = this.peerConnections[peerId]
    if (!pc) return
    this.updateConnectionStatus("reconnecting")
    try {
      const offer = await pc.createOffer({ iceRestart: true })
      await pc.setLocalDescription(offer)
      this.sendSignal(peerId, "offer", pc.localDescription)
    } catch (e) {
      console.error("ICE restart failed:", e)
      this.removePeerConnection(peerId)
    }
  }

  async handleOffer(peerId, payload) {
    peerId = String(peerId)
    const pc = this.createPeerConnection(peerId, false)
    const offerCollision =
      this.makingOffer[peerId] || pc.signalingState !== "stable"
    this.ignoreOffer[peerId] = !this.isPolite(peerId) && offerCollision
    if (this.ignoreOffer[peerId]) return

    try {
      await pc.setRemoteDescription(payload)
      await this.flushIceCandidateQueue(peerId)
      const answer = await pc.createAnswer()
      await pc.setLocalDescription(answer)
      this.sendSignal(peerId, "answer", pc.localDescription)
    } catch (e) {
      console.error("Error handling offer:", e)
    }
  }

  async handleAnswer(peerId, payload) {
    peerId = String(peerId)
    const pc = this.peerConnections[peerId]
    if (!pc) return
    try {
      if (pc.signalingState === "have-local-offer") {
        await pc.setRemoteDescription(payload)
        await this.flushIceCandidateQueue(peerId)
      }
    } catch (e) {
      console.error("Error setting remote description on answer:", e)
    }
  }

  async handleRemoteCandidate(peerId, candidate) {
    peerId = String(peerId)
    const pc = this.peerConnections[peerId]
    if (!pc || !candidate) return
    if (!pc.remoteDescription) {
      this.iceCandidateQueue[peerId] = this.iceCandidateQueue[peerId] || []
      this.iceCandidateQueue[peerId].push(candidate)
      return
    }
    try {
      await pc.addIceCandidate(candidate)
    } catch (e) {
      if (!this.ignoreOffer[peerId]) {
        console.error("Error adding ICE candidate:", e)
      }
    }
  }

  async flushIceCandidateQueue(peerId) {
    const pc = this.peerConnections[peerId]
    const queue = this.iceCandidateQueue[peerId] || []
    this.iceCandidateQueue[peerId] = []
    for (const candidate of queue) {
      try {
        await pc.addIceCandidate(candidate)
      } catch (e) {
        console.error("Error flushing ICE candidate:", e)
      }
    }
  }

  updatePeerConnectionState(peerId, pc) {
    const videoContainer = this.remoteVideosTarget?.querySelector(`[data-peer-id="${peerId}"]`)
    if (!videoContainer) return

    let statusElement = videoContainer.querySelector(".fenetre-peer-status")
    if (!statusElement) {
      statusElement = document.createElement("div")
      statusElement.className = "fenetre-peer-status"
      videoContainer.appendChild(statusElement)
    }

    statusElement.className = "fenetre-peer-status"
    if (pc.connectionState === "connected" || pc.iceConnectionState === "completed") {
      statusElement.classList.add("fenetre-peer-connected")
      statusElement.textContent = "Connected"
    } else if (
      pc.connectionState === "connecting" ||
      pc.iceConnectionState === "checking" ||
      pc.iceConnectionState === "disconnected"
    ) {
      statusElement.classList.add("fenetre-peer-connecting")
      statusElement.textContent =
        pc.iceConnectionState === "disconnected" ? "Reconnecting..." : "Connecting..."
    } else if (pc.connectionState === "failed" || pc.iceConnectionState === "failed") {
      statusElement.classList.add("fenetre-peer-failed")
      statusElement.textContent = "Connection Failed"
    }
  }

  removePeerConnection(peerId) {
    peerId = String(peerId)
    clearTimeout(this.iceRestartTimers[peerId])
    delete this.iceRestartTimers[peerId]
    delete this.makingOffer[peerId]
    delete this.ignoreOffer[peerId]
    delete this.iceCandidateQueue[peerId]
    if (this.peerConnections[peerId]) {
      this.peerConnections[peerId].close()
      delete this.peerConnections[peerId]
    }
    this.remoteVideosTarget
      ?.querySelector(`[data-peer-id="${peerId}"]`)
      ?.remove()
  }

  sendSignal(peerId, type, payload) {
    if (!this.subscription) return
    const plain =
      payload && typeof payload.toJSON === "function" ? payload.toJSON() : payload
    this.subscription.perform("signal", {
      type,
      to: peerId,
      payload: plain,
    })
  }

  addRemoteVideo(peerId, stream) {
    if (!this.hasRemoteVideosTarget) return
    peerId = String(peerId)
    let videoElement = this.remoteVideosTarget.querySelector(
      `[data-peer-id="${peerId}"] video`
    )

    if (!videoElement) {
      const videoContainer = document.createElement("div")
      videoContainer.setAttribute("data-peer-id", peerId)
      videoContainer.className = "fenetre-remote-video-container"

      videoElement = document.createElement("video")
      videoElement.autoplay = true
      videoElement.playsInline = true
      videoElement.setAttribute("playsinline", "")
      videoElement.muted = false

      const peerIdLabel = document.createElement("p")
      peerIdLabel.className = "fenetre-peer-label"
      peerIdLabel.textContent = `User ${peerId}`

      const statusElement = document.createElement("div")
      statusElement.className = "fenetre-peer-status fenetre-peer-connecting"
      statusElement.textContent = "Connecting..."

      videoContainer.appendChild(videoElement)
      videoContainer.appendChild(peerIdLabel)
      videoContainer.appendChild(statusElement)
      this.remoteVideosTarget.appendChild(videoContainer)

      if (this.peerConnections[peerId]) {
        this.updatePeerConnectionState(peerId, this.peerConnections[peerId])
      }
    }

    videoElement.srcObject = stream
    videoElement.play?.().catch(() => {})
  }
}
