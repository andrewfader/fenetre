import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer" // Adjust path if needed based on host app structure

// Connects to data-controller="fenetre--video-chat"
export default class extends Controller {
  static targets = [ "localVideo", "remoteVideos", "roomId" ]
  static values = { userId: String }

  connect() {
    console.log("VideoChat controller connected");
    this.peerConnections = {};
    this.localStream = null;
    this.roomId = this.roomIdTarget.value;

    if (!this.roomId) {
      console.error("Room ID is missing!");
      return;
    }

    this.startLocalVideo()
      .then(() => this.createSubscription())
      .catch(error => console.error("Error initializing video chat:", error));
  }

  disconnect() {
    console.log("VideoChat controller disconnected");
    if (this.subscription) {
      this.subscription.unsubscribe();
    }
    if (this.localStream) {
      this.localStream.getTracks().forEach(track => track.stop());
    }
    Object.values(this.peerConnections).forEach(pc => pc.close());
    this.peerConnections = {};
    this.remoteVideosTarget.innerHTML = ''; // Clear remote videos
  }

  async startLocalVideo() {
    try {
      this.localStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
      this.localVideoTarget.srcObject = this.localStream;
      console.log("Local video stream started");
    } catch (error) {
      console.error("Error accessing media devices.", error);
      // Handle error appropriately (e.g., show a message to the user)
      throw error; // Re-throw to prevent subscription if failed
    }
  }

  createSubscription() {
    this.subscription = consumer.subscriptions.create(
      { channel: "Fenetre::VideoChatChannel", room_id: this.roomId },
      {
        connected: () => {
          console.log(`Connected to ActionCable channel: Fenetre::VideoChatChannel (Room: ${this.roomId})`);
          this.announceJoin();
        },
        disconnected: () => {
          console.log("Disconnected from ActionCable channel");
        },
        received: (data) => {
          console.log("Received data:", data);
          this.handleSignalingData(data);
        },
      }
    );
  }

  announceJoin() {
    console.log("Announcing join");
    this.subscription.perform("join_room", {});
  }

  // --- WebRTC Signaling Logic ---

  handleSignalingData(data) {
    // Turbo Stream UI update support
    if (data.turbo_stream) {
      this.applyTurboStream(data.turbo_stream);
    }

    // Event hooks (can be customized via subclassing or data attributes)
    if (data.type === "join") {
      this.onJoin?.(data);
    } else if (data.type === "leave") {
      this.onLeave?.(data);
    } else if (data.type === "chat") {
      this.onChat?.(data);
    } else if (data.type === "mute" || data.type === "unmute") {
      this.onModeration?.(data);
    } else if (data.type === "raise_hand" || data.type === "lower_hand") {
      this.onHandRaise?.(data);
    }

    // Ignore messages from self
    if (data.from === this.userIdValue) {
      console.log("Ignoring message from self");
      return;
    }

    switch (data.type) {
      case "join":
        console.log(`User ${data.from} joined, sending offer...`);
        this.createPeerConnection(data.from, true); // Create PC and initiate offer
        break;
      case "offer":
        console.log(`Received offer from ${data.from}`);
        this.createPeerConnection(data.from, false); // Create PC
        this.peerConnections[data.from].setRemoteDescription(new RTCSessionDescription(data.payload))
          .then(() => this.peerConnections[data.from].createAnswer())
          .then(answer => this.peerConnections[data.from].setLocalDescription(answer))
          .then(() => {
            console.log(`Sending answer to ${data.from}`);
            this.sendSignal(data.from, "answer", this.peerConnections[data.from].localDescription);
          })
          .catch(error => console.error("Error handling offer:", error));
        break;
      case "answer":
        console.log(`Received answer from ${data.from}`);
        if (this.peerConnections[data.from]) {
          this.peerConnections[data.from].setRemoteDescription(new RTCSessionDescription(data.payload))
            .catch(error => console.error("Error setting remote description on answer:", error));
        } else {
          console.warn(`Received answer from unknown peer: ${data.from}`);
        }
        break;
      case "candidate":
        console.log(`Received ICE candidate from ${data.from}`);
        if (this.peerConnections[data.from]) {
          this.peerConnections[data.from].addIceCandidate(new RTCIceCandidate(data.payload))
            .catch(error => console.error("Error adding received ICE candidate:", error));
        } else {
          console.warn(`Received candidate from unknown peer: ${data.from}`);
        }
        break;
      case "leave":
        console.log(`User ${data.from} left`);
        this.removePeerConnection(data.from);
        break;
      default:
        console.warn("Unknown signal type:", data.type);
    }
  }

  // Turbo Stream support: inject HTML into the DOM
  applyTurboStream(turboStreamHtml) {
    const template = document.createElement('template');
    template.innerHTML = turboStreamHtml.trim();
    const stream = template.content.firstElementChild;
    if (stream && stream.tagName === 'TURBO-STREAM') {
      document.body.appendChild(stream); // Or use Turbo.renderStreamMessage if available
    }
  }

  // Minimal default event handlers (can be overridden)
  onJoin(data) {
    if (data.participants) {
      this.updateParticipantList(data.participants);
    }
  }

  onLeave(data) {
    if (data.participants) {
      this.updateParticipantList(data.participants);
    }
  }

  onChat(data) {
    this.appendChatMessage(data);
  }

  updateParticipantList(participants) {
    // Minimal default: log or update a list if present
    const list = document.getElementById('fenetre-participant-list');
    if (list) {
      list.innerHTML = '';
      participants.forEach(id => {
        const li = document.createElement('li');
        li.textContent = `User ${id}`;
        list.appendChild(li);
      });
    }
  }

  appendChatMessage(data) {
    const chatBox = document.getElementById('fenetre-chat-box');
    if (chatBox) {
      const div = document.createElement('div');
      div.textContent = `User ${data.from}: ${data.message}`;
      chatBox.appendChild(div);
    }
  }

  // Chat functionality
  sendChat(event) {
    event.preventDefault();
    const chatInput = this.element.querySelector('[data-fenetre-video-chat-target="chatInput"]');
    if (!chatInput || !chatInput.value.trim()) return;
    
    const message = chatInput.value.trim();
    console.log(`Sending chat message: ${message}`);
    
    // Send via ActionCable
    this.subscription.perform("send_message", { message });
    
    // Clear input field
    chatInput.value = '';
    
    // Add to local display (optional, usually handled by the broadcast)
    const chatMessages = this.element.querySelector('[data-fenetre-video-chat-target="chatMessages"]');
    if (chatMessages) {
      const messageEl = document.createElement('div');
      messageEl.classList.add('fenetre-chat-message', 'fenetre-chat-message-self');
      messageEl.textContent = `You: ${message}`;
      chatMessages.appendChild(messageEl);
      chatMessages.scrollTop = chatMessages.scrollHeight;
    }
  }

  createPeerConnection(peerId, isOffering) {
    if (this.peerConnections[peerId]) {
      console.log(`Peer connection already exists for ${peerId}`);
      return this.peerConnections[peerId];
    }

    console.log(`Creating peer connection for ${peerId}, offering: ${isOffering}`);
    const pc = new RTCPeerConnection({
      iceServers: [
        { urls: 'stun:stun.l.google.com:19302' } // Example STUN server
        // Add TURN servers here if needed for NAT traversal
      ]
    });
    this.peerConnections[peerId] = pc;

    // Add local stream tracks
    if (this.localStream) {
      this.localStream.getTracks().forEach(track => {
        pc.addTrack(track, this.localStream);
      });
      console.log(`Added local tracks to PC for ${peerId}`);
    } else {
      console.warn("Local stream not available when creating peer connection");
    }

    // Handle incoming remote tracks
    pc.ontrack = (event) => {
      console.log(`Track received from ${peerId}`);
      this.addRemoteVideo(peerId, event.streams[0]);
    };

    // Handle ICE candidates
    pc.onicecandidate = (event) => {
      if (event.candidate) {
        console.log(`Sending ICE candidate to ${peerId}`);
        this.sendSignal(peerId, "candidate", event.candidate);
      } else {
        console.log(`All ICE candidates sent for ${peerId}`);
      }
    };

    pc.oniceconnectionstatechange = () => {
      console.log(`ICE connection state for ${peerId}: ${pc.iceConnectionState}`);
      if (pc.iceConnectionState === 'disconnected' || pc.iceConnectionState === 'closed' || pc.iceConnectionState === 'failed') {
        this.removePeerConnection(peerId);
      }
    };

    pc.onconnectionstatechange = () => {
      console.log(`Connection state for ${peerId}: ${pc.connectionState}`);
       if (pc.connectionState === 'failed' || pc.connectionState === 'disconnected' || pc.connectionState === 'closed') {
         this.removePeerConnection(peerId);
       }
    };

    // If offering, create and send offer
    if (isOffering) {
      pc.createOffer()
        .then(offer => pc.setLocalDescription(offer))
        .then(() => {
          console.log(`Sending offer to ${peerId}`);
          this.sendSignal(peerId, "offer", pc.localDescription);
        })
        .catch(error => console.error("Error creating offer:", error));
    }

    return pc;
  }

  removePeerConnection(peerId) {
    console.log(`Removing peer connection and video for ${peerId}`);
    if (this.peerConnections[peerId]) {
      this.peerConnections[peerId].close();
      delete this.peerConnections[peerId];
    }
    const remoteVideoElement = this.remoteVideosTarget.querySelector(`[data-peer-id="${peerId}"]`);
    if (remoteVideoElement) {
      remoteVideoElement.remove();
    }
  }

  sendSignal(peerId, type, payload) {
    // Note: The channel broadcasts to the room, the server relays it.
    // We don't send directly to a peerId via ActionCable here.
    this.subscription.perform("signal", { type, payload });
    // Log what would be sent if it were direct (for clarity)
    // console.log(`Sending signal to ${peerId}: ${type}`, payload);
  }

  addRemoteVideo(peerId, stream) {
    console.log(`Adding remote video for ${peerId}`);
    let videoElement = this.remoteVideosTarget.querySelector(`[data-peer-id="${peerId}"] video`);

    if (!videoElement) {
      const videoContainer = document.createElement('div');
      videoContainer.setAttribute('data-peer-id', peerId);
      videoContainer.style.display = 'inline-block'; // Basic layout
      videoContainer.style.margin = '5px';

      videoElement = document.createElement('video');
      videoElement.setAttribute('autoplay', '');
      videoElement.setAttribute('playsinline', ''); // Important for mobile
      videoElement.style.width = '200px'; // Example size
      videoElement.style.height = '150px';
      videoElement.muted = false; // Unmute remote streams

      const peerIdLabel = document.createElement('p');
      peerIdLabel.textContent = `User: ${peerId}`;
      peerIdLabel.style.fontSize = '12px';
      peerIdLabel.style.textAlign = 'center';

      videoContainer.appendChild(videoElement);
      videoContainer.appendChild(peerIdLabel);
      this.remoteVideosTarget.appendChild(videoContainer);
    }

    videoElement.srcObject = stream;
  }
}
