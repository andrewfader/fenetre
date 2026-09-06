import { Application } from "@hotwired/stimulus"
import VideoChatController from "fenetre/controllers/video_chat_controller"

export { VideoChatController }

export function register(application) {
  application.register("fenetre--video-chat", VideoChatController)
  return application
}

// Reuse the host's application when available. Import this module once from
// application.js, after the host's Stimulus setup.
export const application = register(window.Stimulus?.application || window.Stimulus || Application.start())
window.Stimulus ||= application
