# Fenetre

A Rails engine that adds WebRTC video chat to your app using ActionCable, Stimulus, and Turbo.

## Requirements

- Ruby 3.4.3 or newer
- Rails 6.1 or newer

## Installation

Add to your Gemfile:

```ruby
gem 'fenetre', github: 'andrewfader/fenetre'
```

Then run:

```sh
bundle install
```

## Setup

Fenetre automatically handles most of the necessary setup when used with `importmap-rails`:

- Mounting the Action Cable server at `/cable` (if not already mounted).
- Making the Stimulus controllers available via the import map.
- Making the view helper available.

**Important:**
- Your host application **must** use `importmap-rails`.
- Your host application's `app/javascript/application.js` should load Stimulus controllers (e.g., contain `import "./controllers"`).
- You still need to configure your main application's Action Cable connection (`app/channels/application_cable/connection.rb`) to identify users correctly, as Fenetre relies on this for authentication and user identification within chat rooms. Here's a typical example using Devise:

```ruby
# app/channels/application_cable/connection.rb
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
      logger.add_tags 'ActionCable', current_user.email # Example tagging
    end

    private

    def find_verified_user
      # Adjust this based on your authentication setup (e.g., Devise, Sorcery, etc.)
      if verified_user = env['warden'].user
        verified_user
      else
        reject_unauthorized_connection
      end
    end
  end
end
```

## Usage

No manual JavaScript setup (like `javascript_include_tag` for the engine or adding assets to `config/initializers/assets.rb`) is required if you are using `importmap-rails`.

### Basic Video Chat

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
  # Add other options as needed based on helper definition
) %>
```

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

## Features

- ✅ WebRTC video/audio streaming
- ✅ Action Cable for signaling and chat
- ✅ Stimulus controller for UI logic
- ✅ Simple view helper integration
- ✅ Basic text chat
- ✅ Media controls (video/audio toggle)
- ✅ Dark/light theme support (via CSS)

## Troubleshooting

- **"Could not find channel Fenetre::VideoChatChannel"**: Ensure your Action Cable setup is correct and the gem is properly loaded.
- **Device Access Issues**: WebRTC requires HTTPS (except for localhost). Check browser permissions.
- **Connection Problems**: Inspect the browser's console and network tabs for Action Cable or WebRTC errors.
- **Authentication Errors**: Verify your `ApplicationCable::Connection` correctly identifies the `current_user`.

## License

MIT
