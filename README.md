# Fenetre: WebRTC Video Chat for Rails with Hotwire, Turbo, and Stimulus

Fenetre is a Rails engine that provides real-time, multi-user video chat using WebRTC, ActionCable, Turbo Streams, and Stimulus. It is designed for easy integration into Rails apps and supports modern features for real-world video chat scenarios.

## Features
- WebRTC signaling over ActionCable
- Turbo Streams and Stimulus integration
- Room locking (private rooms)
- User roles (host, guest)
- Room metadata (topic, max participants)
- Customizable signaling actions
- Extensible for presence, moderation, and more

## Installation
Add to your Gemfile:

```ruby
gem 'fenetre', path: 'path/to/your/fenetre'
```

Then bundle install:

```sh
bundle install
```

Mount the engine in your `config/routes.rb` if needed:

```ruby
mount Fenetre::Engine, at: "/fenetre"
```

## Usage

### Helper
Render a video chat container in your view:

```erb
<%= fenetre_video_chat_container(room_id, current_user.id) %>
```

### Channel Subscription (with meta options)
Subscribe to a room with options:

```js
consumer.subscriptions.create({
  channel: "Fenetre::VideoChatChannel",
  room_id: "my-room-123",
  room_locked: true, // lock the room (optional)
  room_topic: "Math Help", // metadata (optional)
  max_participants: 5 // metadata (optional)
});
```

### User Roles
Set user roles (host/guest) in your connection logic. Example:

```ruby
# In ApplicationCable::Connection
identified_by :current_user, :user_role

def connect
  self.current_user = find_verified_user
  self.user_role = current_user.admin? ? :host : :guest
end
```

### Room Locking
- If `room_locked: true` is passed, only users with `user_role: :host` can join.
- Guests are rejected if the room is locked.

### Room Metadata
- When a user joins, the channel can broadcast metadata (e.g., topic, max_participants) to all clients.

### Custom Signaling
Send custom signaling messages (e.g., offer, answer, candidate, raise_hand):

```js
subscription.perform("signal", { type: "offer", payload: { sdp: ... } });
```

## Turbo/Stimulus Integration & Minimal UI

Fenetre comes with a modern Stimulus controller and Turbo Stream support for a seamless, reactive video chat experience. The default UI includes:

- Participant list (auto-updated)
- Chat box (auto-updated)
- Local and remote video sections
- Sensible defaults for auto-joining and signaling

### Usage Example

In your view:

```erb
<%= fenetre_video_chat_container(room_id, current_user.id) %>
```

This will render the full video chat UI, including:
- A participant list (`<ul id="fenetre-participant-list">`)
- A chat box (`<div id="fenetre-chat-box">`)
- Local and remote video containers
- All necessary styles and JS hooks

### Theme Configuration

You can switch between dark and light themes:

```erb
<%= fenetre_video_chat_container(room_id, current_user.id, theme: 'light') %>
```

Or use the default dark theme:

```erb
<%= fenetre_video_chat_container(room_id, current_user.id) %>
```

#### Runtime Theme Switching

To allow users to toggle themes at runtime, you can update the container's class and data attribute:

```js
const container = document.querySelector('.fenetre-video-chat-container');
container.classList.remove('fenetre-theme-dark', 'fenetre-theme-light');
container.classList.add('fenetre-theme-light'); // or 'fenetre-theme-dark'
container.dataset.fenetreTheme = 'light'; // or 'dark'
```

### Customization

- You can override event handlers in the Stimulus controller by subclassing or using data attributes.
- The UI is fully customizable via CSS and HTML structure.
- Turbo Stream payloads can be used for advanced UI updates.

### Stylesheet

The styles are located in:

```
app/assets/stylesheets/fenetre/video_chat.css
```

and are automatically included when you use the helper.

## Configuration
You can extend the channel/controller to support:
- Custom ICE servers
- Timeouts
- Moderation actions (kick, mute, etc.)
- Presence and participant lists

## Example Turbo Stream Integration
You can use Turbo Streams to update the UI when users join/leave:

```ruby
# In your channel
ActionCable.server.broadcast(
  "fenetre_video_chat_#{@room_id}",
  { type: 'join', from: current_user.id, turbo_stream: render_to_string(...)}
)
```

## Status & Health Endpoints

Fenetre provides a mountable status engine for health checks and monitoring. You can mount it in your main app's `routes.rb`:

```ruby
mount Fenetre::AutomaticEngine => "/fenetre-status"
```

This exposes two endpoints:

- **JSON status:** `/fenetre-status/status` — returns `{ status: "ok", time: ..., version: ... }`
- **Human-readable status:** `/fenetre-status/human_status` — returns an HTML page with status info

These endpoints are useful for uptime monitoring, health checks, and debugging.

## Advanced Features

Fenetre is designed for real-world video chat applications and includes:

- **Room locking:** Only hosts can join locked rooms; guests are rejected.
- **User roles:** Host/guest logic for moderation and permissions.
- **Room metadata:** Broadcasts topic, max participants, and more.
- **Presence:** Join/leave notifications and real-time participant lists.
- **Moderation:** Kick, mute, and unmute actions for hosts.
- **Custom signaling:** Support for WebRTC and custom events (e.g., raise/lower hand).
- **Hand-raise queue:** Broadcasts hand-raise/lower events for UI queues.
- **Turbo Stream UI updates:** Example Turbo Stream payloads for live UI changes.
- **Chat messaging:** In-room chat messages broadcast to all participants.
- **Analytics hooks:** Easily track join/leave and moderation events for analytics or auditing.

See the test suite (`test/channels/fenetre/video_chat_channel_test.rb`) for examples of all supported scenarios and meta options.

## Testing
Fenetre is developed using TDD. See `test/channels/fenetre/video_chat_channel_test.rb` for real-world scenarios and meta options.

## License
MIT
