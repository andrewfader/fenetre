import { Application } from "@hotwired/stimulus"
import VideoChatController from "../../javascript/controllers/fenetre/video_chat_controller.js"

window.Stimulus = window.Stimulus || Application.start()
window.Stimulus.register("fenetre--video-chat", VideoChatController)
