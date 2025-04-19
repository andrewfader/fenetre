// Import necessary libraries and controllers
import { Application } from "@hotwired/stimulus"
import VideoChatController from "controllers/fenetre/video_chat_controller"

// Initialize Stimulus application
window.Stimulus = window.Stimulus || Application.start()

// Register controllers
window.Stimulus.register("fenetre--video-chat", VideoChatController)
