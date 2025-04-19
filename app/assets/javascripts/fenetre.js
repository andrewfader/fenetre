// Import necessary libraries and controllers
// Using import maps for library dependencies
import { Application } from "@hotwired/stimulus"
import { Controller } from "@hotwired/stimulus"
import VideoChatController from "../javascript/controllers/fenetre/video_chat_controller"

// Initialize Stimulus application
window.Stimulus = window.Stimulus || Application.start()

// Register controllers
window.Stimulus.register("fenetre--video-chat", VideoChatController)
