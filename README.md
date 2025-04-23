# Fenetre

[![CI Status](https://github.com/andrewfader/fenetre/workflows/CI/badge.svg)](https://github.com/andrewfader/fenetre/actions)
[![Coverage Status](https://img.shields.io/badge/coverage-90.2%25-yellow.svg)](coverage/index.html)

A Rails engine that adds WebRTC video chat to your app using ActionCable, Stimulus, and Turbo.

## Setup

Fenetre automatically handles most of the necessary setup when used with `importmap-rails`:

- Mounting the Action Cable server at `/cable` (if not already mounted).
- Making the Stimulus controllers available via the import map.
- Making the view helper available.

**Important:**
- Your host application **must** use `importmap-rails`.
- Your host application's `app/javascript/application.js` should load Stimulus controllers (e.g., contain `import "./controllers"`).

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
## License

MIT
