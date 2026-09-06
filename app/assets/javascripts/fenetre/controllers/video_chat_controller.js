import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// Connects to data-controller="fenetre--video-chat"
export default class extends Controller {
  static targets = [
    "localVideo",
    "remoteVideos",
    "roomId",
    "chatInput",
    "chatMessages",
    "connectionStatus",
    "participants",
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
    this.peerConnections = Object.create(null)
    this.makingOffer = Object.create(null)
    this.settingRemoteAnswer = Object.create(null)
    this.ignoreOffer = Object.create(null)
    this.iceCandidateQueue = Object.create(null)
    this.iceRestartTimers = Object.create(null)
    this.active = true
    this.generation = (this.generation || 0) + 1
    this.localStream = null
    this.screenStream = null
    this.isScreenSharing = false
    this.savedVideoTrack = null

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

    const generation = this.generation
    this.startLocalVideo(generation)
      .then(() => {
        if (this.active && this.generation === generation) this.createSubscription()
      })
      .catch((error) => {
        if (this.active && this.generation === generation) this.handleMediaError(error)
      })
  }

  disconnect() {
    this.active = false
    this.generation = (this.generation || 0) + 1
    Object.keys(this.iceRestartTimers || {}).forEach((id) => {
      clearTimeout(this.iceRestartTimers[id])
    })
    this.iceRestartTimers = Object.create(null)

    if (this.subscription) {
      this.subscription.unsubscribe?.()
      this.subscription = null
    }
    this._consumer?.disconnect()
    this._consumer = null
    this.savedVideoTrack?.stop()
    this.savedVideoTrack = null
    if (this.localStream) {
      this.localStream.getTracks().forEach((t) => t.stop())
      this.localStream = null
    }
    if (this.screenStream) {
      this.screenStream.getTracks().forEach((t) => t.stop())
      this.screenStream = null
    }
    Object.keys(this.peerConnections).forEach((id) => this.removePeerConnection(id))
    if (this.hasLocalVideoTarget) this.localVideoTarget.srcObject = null
    this.peerConnections = Object.create(null)
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

  async startLocalVideo(generation = this.generation) {
    const stream = await navigator.mediaDevices.getUserMedia(this.mediaConstraints())
    if (!this.active || this.generation !== generation) {
      stream.getTracks().forEach((track) => track.stop())
      return
    }
    this.localStream = stream
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
    const consumer = this._consumer ||= createConsumer()

    this.subscription = consumer.subscriptions.create(
      { channel: "Fenetre::VideoChatChannel", room_id: this.roomId },
      {
        connected: () => {
          this.updateConnectionStatus("connected")
          this.announceJoin()
        },
        disconnected: () => {
          Object.keys(this.peerConnections).forEach((id) => this.removePeerConnection(id))
          this.updateConnectionStatus("reconnecting")
        },
        rejected: () => {
          this.disconnect()
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

    const from = data.from != null ? String(data.from) : null
    const to = data.to != null ? String(data.to) : null
    const selfId = String(this.userIdValue)
    if (to && to !== selfId) return

    if (data.type === "join") this.onJoin(data)
    if (data.type === "leave") this.onLeave(data)
    if (!from || from === selfId) return
    if (data.type === "chat") this.onChat(data)

    switch (data.type) {
      case "join":
        // Existing peers offer to the joiner (mesh).
        this.createPeerConnection(from)
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
        if (!data.participants?.map(String).includes(from)) this.removePeerConnection(from)
        break
      case "kick":
        this.disconnect()
        this.connectionStatusTarget.textContent = "Removed from room"
        break
      case "mute":
        if (this.localStream?.getAudioTracks()[0]?.enabled) this.toggleAudio()
        break
      case "unmute":
        this.dispatch("unmute-requested", { detail: { from } })
        break
      default:
        break
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
    if (!this.hasParticipantsTarget) return
    const list = this.participantsTarget
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

    if (this.subscription.perform("send_message", { message }) === false) return
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
    if (this.isScreenSharing) return this.stopScreenSharing()
    return this.startScreenSharing()
  }

  async startScreenSharing() {
    if (this.startingScreenShare || this.isScreenSharing || !this.localStream) return
    this.startingScreenShare = true
    const generation = this.generation
    try {
      const stream = await navigator.mediaDevices.getDisplayMedia({
        video: {
          cursor: "always",
          width: { ideal: 1920 },
          height: { ideal: 1080 },
          frameRate: { ideal: 30, max: 60 },
        },
        audio: false,
      })

      if (!this.active || this.generation !== generation) {
        stream.getTracks().forEach((track) => track.stop())
        return
      }
      this.screenStream = stream
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
      this.screenStream?.getTracks().forEach((track) => track.stop())
      this.screenStream = null
      if (error.name !== "NotAllowedError") console.error("Error starting screen share:", error)
    } finally {
      this.startingScreenShare = false
    }
  }

  async stopScreenSharing() {
    if (!this.isScreenSharing) return
    this.isScreenSharing = false
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
    const servers = this.iceServersValue
    return {
      iceServers: servers,
      iceCandidatePoolSize: 4,
      bundlePolicy: "max-bundle",
      rtcpMuxPolicy: "require",
    }
  }

  createPeerConnection(peerId) {
    peerId = String(peerId)
    if (this.peerConnections[peerId]) {
      return this.peerConnections[peerId]
    }

    const pc = new RTCPeerConnection(this.iceConfiguration())
    this.peerConnections[peerId] = pc
    this.iceCandidateQueue[peerId] ||= []
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

    return pc
  }

  async makeOffer(peerId) {
    const pc = this.peerConnections[peerId]
    if (!pc || this.makingOffer[peerId] || pc.signalingState !== "stable") return
    try {
      this.makingOffer[peerId] = true
      await pc.setLocalDescription()
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
    pc.restartIce()
  }

  async handleOffer(peerId, payload) {
    peerId = String(peerId)
    const pc = this.createPeerConnection(peerId)
    const offerCollision =
      this.makingOffer[peerId] || (pc.signalingState !== "stable" && !this.settingRemoteAnswer[peerId])
    this.ignoreOffer[peerId] = !this.isPolite(peerId) && offerCollision
    if (this.ignoreOffer[peerId]) return

    try {
      await pc.setRemoteDescription(payload)
      await this.flushIceCandidateQueue(peerId)
      await pc.setLocalDescription()
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
        this.settingRemoteAnswer[peerId] = true
        await pc.setRemoteDescription(payload)
        this.settingRemoteAnswer[peerId] = false
        await this.flushIceCandidateQueue(peerId)
      }
    } catch (e) {
      console.error("Error setting remote description on answer:", e)
    } finally {
      this.settingRemoteAnswer[peerId] = false
    }
  }

  async handleRemoteCandidate(peerId, candidate) {
    peerId = String(peerId)
    const pc = this.peerConnections[peerId]
    if (!candidate || this.ignoreOffer[peerId]) return
    if (!pc?.remoteDescription) {
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
    if (!this.hasRemoteVideosTarget) return
    const videoContainer = this.remoteVideosTarget.querySelector(`[data-peer-id="${CSS.escape(String(peerId))}"]`)
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
    delete this.settingRemoteAnswer[peerId]
    delete this.ignoreOffer[peerId]
    delete this.iceCandidateQueue[peerId]
    if (this.peerConnections[peerId]) {
      const pc = this.peerConnections[peerId]
      delete this.peerConnections[peerId]
      pc.oniceconnectionstatechange = null
      pc.onconnectionstatechange = null
      pc.onnegotiationneeded = null
      pc.onicecandidate = null
      pc.ontrack = null
      pc.close()
    }
    if (this.hasRemoteVideosTarget) this.remoteVideosTarget
      .querySelector(`[data-peer-id="${CSS.escape(String(peerId))}"]`)
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
      `[data-peer-id="${CSS.escape(String(peerId))}"] video`
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
