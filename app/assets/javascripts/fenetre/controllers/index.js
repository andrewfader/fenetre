// This file loads all Stimulus controllers in the fenetre engine
// It's referenced by the importmap

import { Application } from "../vendor/stimulus.umd.js"
import VideoChatController from "./video_chat_controller.js"

const application = Application.start();

// Register controllers with Stimulus
application.register("fenetre--video-chat", VideoChatController)

// Expose the Stimulus application globally for testing and debugging
// This allows tests to access controllers through window.Stimulus.application
if (typeof window !== 'undefined') {
  window.Stimulus = window.Stimulus || {};
  window.Stimulus.application = application;
}

export { application };