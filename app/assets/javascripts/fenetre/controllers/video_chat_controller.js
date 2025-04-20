import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="fenetre--video-chat"
export default class extends Controller {
  static targets = [ "localVideo", "remoteVideos", "roomId", "chatInput", "chatMessages", "connectionStatus" ]
  static values = { userId: String }

  connect() {
    console.log("VideoChat controller connected");
    this.peerConnections = {};
    this.localStream = null;
    this.screenStream = null;
    this.isScreenSharing = false;
    this.roomId = this.roomIdTarget.value;

    if (!this.roomId) {
      console.error("Room ID is missing!");
      return;
    }

    this.updateConnectionStatus('connecting');
    
    // Listen for ActionCable connection events
    this.setupConnectionEventListeners();
    
    this.startLocalVideo()
      .then(() => this.createSubscription())
      .catch(error => this.handleMediaError(error));
  }

  // Set up listeners for ActionCable connection events
  setupConnectionEventListeners() {
    // Listen for ActionCable connected event
    document.addEventListener('cable-ready:connected', this.handleActionCableConnected.bind(this));
    
    // Listen for ActionCable disconnected event
    document.addEventListener('cable-ready:disconnected', this.handleActionCableDisconnected.bind(this));
    
    // Listen for screen sharing status changes (for testing)
    document.addEventListener('screen-sharing-changed', this.handleScreenSharingChange.bind(this));
  }
  
  // Handle ActionCable connected event
  handleActionCableConnected(event) {
    console.log('ActionCable connected:', event);
    this.updateConnectionStatus('connected');
  }
  
  // Handle ActionCable disconnected event
  handleActionCableDisconnected(event) {
    console.log('ActionCable disconnected:', event);
    this.updateConnectionStatus('disconnected');
  }
  
  // Handle screen sharing status change (for testing)
  handleScreenSharingChange(event) {
    console.log('Screen sharing status changed:', event.detail.status);
    if (event.detail.status === 'started') {
      const button = this.element.querySelector('button[data-action*="fenetre--video-chat#toggleScreenShare"]');
      if (button) {
        button.classList.add('screen-sharing');
        button.textContent = 'Stop Sharing';
      }
    } else if (event.detail.status === 'stopped') {
      const button = this.element.querySelector('button[data-action*="fenetre--video-chat#toggleScreenShare"]');
      if (button) {
        button.classList.remove('screen-sharing');
        button.textContent = 'Share Screen';
      }
    }
  }
  
  disconnect() {
    console.log("VideoChat controller disconnected");
    
    // Remove event listeners
    document.removeEventListener('cable-ready:connected', this.handleActionCableConnected);
    document.removeEventListener('cable-ready:disconnected', this.handleActionCableDisconnected);
    document.removeEventListener('screen-sharing-changed', this.handleScreenSharingChange);
    
    if (this.subscription) {
      this.subscription.unsubscribe();
    }
    if (this.localStream) {
      this.localStream.getTracks().forEach(track => track.stop());
    }
    if (this.screenStream) {
      this.screenStream.getTracks().forEach(track => track.stop());
    }
    Object.values(this.peerConnections).forEach(pc => pc.close());
    this.peerConnections = {};
    this.remoteVideosTarget.innerHTML = ''; // Clear remote videos
    this.updateConnectionStatus('disconnected');
  }

  updateConnectionStatus(status) {
    if (this.hasConnectionStatusTarget) {
      const statusElement = this.connectionStatusTarget;
      
      // Clear previous status classes
      statusElement.classList.remove('fenetre-status-connecting', 'fenetre-status-connected', 
                                    'fenetre-status-disconnected', 'fenetre-status-reconnecting',
                                    'fenetre-status-error');
      
      // Add appropriate class and text based on status
      switch(status) {
        case 'connecting':
          statusElement.classList.add('fenetre-status-connecting');
          statusElement.textContent = 'Connecting...';
          break;
        case 'connected':
          statusElement.classList.add('fenetre-status-connected');
          statusElement.textContent = 'Connected';
          break;
        case 'disconnected':
          statusElement.classList.add('fenetre-status-disconnected');
          statusElement.textContent = 'Disconnected';
          break;
        case 'reconnecting':
          statusElement.classList.add('fenetre-status-reconnecting');
          statusElement.textContent = 'Reconnecting...';
          break;
        case 'error':
          statusElement.classList.add('fenetre-status-error');
          statusElement.textContent = 'Connection Error';
          break;
      }
    }
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

  handleMediaError(error) {
    console.error("Media access error:", error);
    // Show user-friendly error message
    const errorMessage = document.createElement('div');
    errorMessage.className = 'fenetre-media-error';
    errorMessage.textContent = "Could not access camera or microphone. Please check your device permissions.";
    errorMessage.style.color = 'red';
    errorMessage.style.padding = '10px';
    errorMessage.style.margin = '10px 0';
    errorMessage.style.backgroundColor = '#ffeeee';
    errorMessage.style.border = '1px solid red';
    this.element.insertBefore(errorMessage, this.element.firstChild);
  }

  createSubscription() {
    if (!window.ActionCable) {
      console.error("ActionCable not available. Make sure it's properly loaded in your application.");
      this.updateConnectionStatus('error');
      return;
    }

    this.subscription = window.ActionCable.createConsumer().subscriptions.create(
      { channel: "Fenetre::VideoChatChannel", room_id: this.roomId },
      {
        connected: () => {
          console.log(`Connected to ActionCable channel: Fenetre::VideoChatChannel (Room: ${this.roomId})`);
          this.updateConnectionStatus('connected');
          this.announceJoin();
        },
        disconnected: () => {
          console.log("Disconnected from ActionCable channel");
          this.updateConnectionStatus('disconnected');
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
    if (!this.hasChatMessagesTarget) return;
    
    const messageEl = document.createElement('div');
    messageEl.className = 'fenetre-chat-message';
    messageEl.textContent = `${data.from}: ${data.message}`;
    this.chatMessagesTarget.appendChild(messageEl);
    this.chatMessagesTarget.scrollTop = this.chatMessagesTarget.scrollHeight;
  }

  // Chat functionality
  sendChat(event) {
    event.preventDefault();
    
    if (!this.hasChatInputTarget) {
      console.error("Chat input target not found!");
      return;
    }
    
    const message = this.chatInputTarget.value.trim();
    if (!message) return;
    
    // Send via ActionCable
    if (this.subscription) {
      this.subscription.perform("send_message", { message });
      
      // Clear input field
      this.chatInputTarget.value = "";
      
      // Add to local display
      if (this.hasChatMessagesTarget) {
        const messageEl = document.createElement('div');
        messageEl.className = 'fenetre-chat-message fenetre-chat-message-self';
        messageEl.textContent = "You: " + message;
        this.chatMessagesTarget.appendChild(messageEl);
        this.chatMessagesTarget.scrollTop = this.chatMessagesTarget.scrollHeight;
      }
    } else {
      console.warn("Subscription not available for sending message");
    }
  }
  
  // Video toggle functionality
  toggleVideo() {
    if (this.localStream) {
      const videoTracks = this.localStream.getVideoTracks();
      if (videoTracks.length > 0) {
        const track = videoTracks[0];
        track.enabled = !track.enabled;
        
        // Update UI to reflect current state
        const button = this.element.querySelector('button[data-action*="fenetre--video-chat#toggleVideo"]');
        if (button) {
          button.classList.toggle('video-off', !track.enabled);
          button.setAttribute('aria-label', track.enabled ? 'Turn off camera' : 'Turn on camera');
        }
      }
    }
  }
  
  // Audio toggle functionality
  toggleAudio() {
    if (this.localStream) {
      const audioTracks = this.localStream.getAudioTracks();
      if (audioTracks.length > 0) {
        const track = audioTracks[0];
        track.enabled = !track.enabled;
        
        // Update UI to reflect current state
        const button = this.element.querySelector('button[data-action*="fenetre--video-chat#toggleAudio"]');
        if (button) {
          button.classList.toggle('audio-off', !track.enabled);
          button.setAttribute('aria-label', track.enabled ? 'Mute microphone' : 'Unmute microphone');
        }
      }
    }
  }

  // Screen sharing functionality
  toggleScreenShare() {
    if (this.isScreenSharing) {
      this.stopScreenSharing();
    } else {
      this.startScreenSharing();
    }
  }

  async startScreenSharing() {
    try {
      // Get screen sharing stream
      this.screenStream = await navigator.mediaDevices.getDisplayMedia({ 
        video: { 
          cursor: "always",
          displaySurface: "monitor" 
        },
        audio: false 
      });

      // Save current video stream for later
      this.savedVideoTrack = this.localStream.getVideoTracks()[0];
      
      // Replace video track in local stream with screen share track
      const screenTrack = this.screenStream.getVideoTracks()[0];
      
      // Replace track in all peer connections
      Object.values(this.peerConnections).forEach(pc => {
        const senders = pc.getSenders();
        const videoSender = senders.find(sender => 
          sender.track && sender.track.kind === 'video'
        );
        
        if (videoSender) {
          videoSender.replaceTrack(screenTrack);
        }
      });
      
      // Replace track in local video
      this.localStream.removeTrack(this.savedVideoTrack);
      this.localStream.addTrack(screenTrack);
      
      // Show local screen share
      this.localVideoTarget.srcObject = this.localStream;
      
      // Update UI
      const button = this.element.querySelector('button[data-action*="fenetre--video-chat#toggleScreenShare"]');
      if (button) {
        button.classList.add('screen-sharing');
        button.setAttribute('aria-label', 'Stop screen sharing');
        button.textContent = 'Stop Sharing';
      }
      
      this.isScreenSharing = true;
      
      // Handle case when user stops sharing via browser UI
      screenTrack.onended = () => {
        this.stopScreenSharing();
      };
      
    } catch (error) {
      console.error("Error starting screen share:", error);
    }
  }

  stopScreenSharing() {
    if (!this.isScreenSharing || !this.screenStream || !this.savedVideoTrack) {
      return;
    }
    
    try {
      // Stop all tracks in screen stream
      this.screenStream.getTracks().forEach(track => track.stop());
      
      // Remove screen sharing track from local stream
      const screenTrack = this.localStream.getVideoTracks()[0];
      if (screenTrack) {
        this.localStream.removeTrack(screenTrack);
      }
      
      // Add back the original camera video track
      this.localStream.addTrack(this.savedVideoTrack);
      
      // Replace track in all peer connections
      Object.values(this.peerConnections).forEach(pc => {
        const senders = pc.getSenders();
        const videoSender = senders.find(sender => 
          sender.track && sender.track.kind === 'video'
        );
        
        if (videoSender) {
          videoSender.replaceTrack(this.savedVideoTrack);
        }
      });
      
      // Update local video
      this.localVideoTarget.srcObject = this.localStream;
      
      // Update UI
      const button = this.element.querySelector('button[data-action*="fenetre--video-chat#toggleScreenShare"]');
      if (button) {
        button.classList.remove('screen-sharing');
        button.setAttribute('aria-label', 'Share screen');
        button.textContent = 'Share Screen';
      }
      
      this.isScreenSharing = false;
      this.screenStream = null;
      
    } catch (error) {
      console.error("Error stopping screen share:", error);
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
      
      // Update connection status UI for this peer
      this.updatePeerConnectionState(peerId, pc);
      
      if (pc.iceConnectionState === 'disconnected' || pc.iceConnectionState === 'closed' || pc.iceConnectionState === 'failed') {
        this.removePeerConnection(peerId);
      }
    };

    pc.onconnectionstatechange = () => {
      console.log(`Connection state for ${peerId}: ${pc.connectionState}`);
      
      // Update connection status UI for this peer
      this.updatePeerConnectionState(peerId, pc);
      
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

  updatePeerConnectionState(peerId, pc) {
    // Find the status indicator for this peer
    const videoContainer = this.remoteVideosTarget.querySelector(`[data-peer-id="${peerId}"]`);
    if (!videoContainer) return;
    
    let statusElement = videoContainer.querySelector('.fenetre-peer-status');
    if (!statusElement) {
      statusElement = document.createElement('div');
      statusElement.className = 'fenetre-peer-status';
      videoContainer.appendChild(statusElement);
    }
    
    // Clear previous classes
    statusElement.className = 'fenetre-peer-status';
    
    // Set status based on connection state
    if (pc.connectionState === 'connected') {
      statusElement.classList.add('fenetre-peer-connected');
      statusElement.textContent = 'Connected';
    } else if (pc.connectionState === 'connecting' || pc.iceConnectionState === 'checking') {
      statusElement.classList.add('fenetre-peer-connecting');
      statusElement.textContent = 'Connecting...';
    } else if (pc.connectionState === 'disconnected' || pc.iceConnectionState === 'disconnected') {
      statusElement.classList.add('fenetre-peer-disconnected');
      statusElement.textContent = 'Disconnected';
    } else if (pc.connectionState === 'failed' || pc.iceConnectionState === 'failed') {
      statusElement.classList.add('fenetre-peer-failed');
      statusElement.textContent = 'Connection Failed';
    }
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
      videoContainer.className = 'fenetre-remote-video-container';
      videoContainer.style.display = 'inline-block'; // Basic layout
      videoContainer.style.margin = '5px';
      videoContainer.style.position = 'relative';

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
      
      // Add connection status indicator
      const statusElement = document.createElement('div');
      statusElement.className = 'fenetre-peer-status fenetre-peer-connecting';
      statusElement.textContent = 'Connecting...';
      
      videoContainer.appendChild(videoElement);
      videoContainer.appendChild(peerIdLabel);
      videoContainer.appendChild(statusElement);
      this.remoteVideosTarget.appendChild(videoContainer);
      
      // Update connection state for this new peer
      if (this.peerConnections[peerId]) {
        this.updatePeerConnectionState(peerId, this.peerConnections[peerId]);
      }
    }

    videoElement.srcObject = stream;
  }
}
