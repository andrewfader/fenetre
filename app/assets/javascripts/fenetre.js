// Import necessary libraries and controllers
// Using import maps for library dependencies
import { Application, Controller } from "./fenetre/vendor/stimulus.min.js"
import VideoChatController from "../../javascript/controllers/fenetre/video_chat_controller.js"

// Initialize Stimulus application
window.Stimulus = window.Stimulus || Application.start()

// Register controllers
window.Stimulus.register("fenetre--video-chat", VideoChatController)
