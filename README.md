# Fenetre

[![CI Status](https://github.com/andrewfader/fenetre/workflows/CI/badge.svg)](https://github.com/andrewfader/fenetre/actions)
[![Coverage Status](https://img.shields.io/badge/coverage-90.2%25-yellow.svg)](coverage/index.html)

A Rails engine that adds WebRTC video chat to your app using ActionCable, Stimulus, and Turbo.

## Setup

Add the gem, then import it once from your entrypoint:

```javascript
// app/javascript/application.js
import "fenetre"
```

That single import registers the `fenetre--video-chat` Stimulus controller on your
application (it reuses `window.Stimulus` when your app already started one).

The engine adds its own pins to the host import map, so no `bin/importmap pin`
is needed for `fenetre`, `@hotwired/stimulus`, or `@rails/actioncable`.

**Requirements:**
- Your host application uses `importmap-rails` and `propshaft`.
- Action Cable is mounted (Rails mounts it at `/cable` by default).
- Your `ApplicationCable::Connection` identifies `current_user` — the channel rejects
  anonymous subscriptions. Identify `user_role` too if you want moderation:

```ruby
# app/channels/application_cable/connection.rb
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :user_role

    def connect
      self.current_user = User.find_by(id: cookies.encrypted[:user_id]) || reject_unauthorized_connection
      self.user_role = current_user.host? ? :host : :guest
    end
  end
end
```

Add the video chat container helper to any view where you want the chat interface:

```erb
<%# Assuming you have `room_id` and `current_user` available %>
<%= fenetre_video_chat_container(room_id, current_user.id) %>
```

This renders a complete video chat UI. The necessary Stimulus controller (`fenetre--video-chat`) will be automatically loaded.

### Room Options

Customize the video chat experience using options:

```erb
<%= fenetre_video_chat_container(
  room_id,
  current_user.id,
  theme: 'light',                   # 'dark' (default) or 'light'
  ice_servers: [                    # optional override; prefer Fenetre.configure
    { urls: 'stun:stun.l.google.com:19302' },
    { urls: 'turn:turn.example.com:3478', username: 'u', credential: 'p' }
  ]
) %>
```

### ICE / TURN (required for real networks)

STUN alone is not enough for many NATs. Configure TURN in an initializer:

```ruby
# config/initializers/fenetre.rb
Fenetre.configure do |c|
  c.ice_servers = [
    { urls: 'stun:stun.l.google.com:19302' },
    { urls: 'turn:turn.example.com:3478', username: ENV.fetch('TURN_USER'), credential: ENV.fetch('TURN_PASS') }
  ]
  c.video_width = 1280
  c.video_height = 720
  c.frame_rate = 30
  c.max_video_bitrate = 2_500_000
  c.max_audio_bitrate = 128_000
end
```

### Room policy lives on the server

Nothing a browser sends decides who gets in, how many people fit, or who may
moderate. Configure that in an initializer:

```ruby
# config/initializers/fenetre.rb
Fenetre.configure do |c|
  # Return false to reject the subscription outright.
  c.authorize_room = ->(user, room_id) { Room.find_by(slug: room_id)&.member?(user) }

  # Per-room settings, evaluated on every subscription.
  c.room_options = lambda do |user, room_id|
    {
      max_participants: 8,          # join is refused atomically once the room is full
      room_locked: false,           # when true, only a :host connection may subscribe
      enable_private_chat: true,    # required before a directed chat message is delivered
      enable_screen_sharing: true,  # false drops screen_share signals
      room_topic: 'Daily standup'   # broadcast with the join message
    }
  end
end
```

Directed chat and moderation (`kick`, `mute`, `unmute`) are delivered only to the
target user's own stream, and only a connection whose `user_role` is `:host` may
moderate. Chat is trimmed to 2000 characters and always rendered as text.

### Presence across processes

The default presence store is process-local, which is correct for a single Puma
process and wrong for anything larger. Supply your own store with the same two
atomic methods (`join(room, user, limit)` returning the participant list or `nil`
when full, and `leave(room, user)`), backed by Redis or your database:

```ruby
Fenetre.presence = MyRedisPresence.new
```

### Instrumentation

`join.fenetre` and `leave.fenetre` are emitted through `ActiveSupport::Notifications`
with `user_id` and `room_id` payloads.

### JavaScript Interaction (Optional)

While Fenetre works out-of-the-box, you can interact with the Stimulus controller (`fenetre--video-chat`) for advanced customization:

```javascript
// In your application's JavaScript or another Stimulus controller
import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  connect() {
    const fenetreElement = this.element.querySelector('[data-controller="fenetre--video-chat"]');
    if (fenetreElement) {
      const fenetreController = this.application.getControllerForElementAndIdentifier(fenetreElement, 'fenetre--video-chat');
      // Now you can interact with fenetreController if needed
      console.log('Fenetre controller found:', fenetreController);

      // Example: Listen for custom events (if implemented in the controller)
      // fenetreElement.addEventListener('fenetre:user-joined', (event) => {
      //   console.log(`User ${event.detail.userId} joined`);
      // });
    }
  }
}
```

## Styling

The default styling is included automatically. You can override the CSS classes for custom themes:

```css
/* Example overrides */
.fenetre-video-chat-container {
  border: 2px solid blue;
}

.fenetre-theme-light .fenetre-chat-messages {
  background-color: #f0f0f0;
}
```
## License

MIT
