// This file loads all Stimulus controllers in the fenetre engine
// It's referenced by the importmap

import { application } from "@hotwired/stimulus"
import VideoChatController from "../../javascript/controllers/fenetre/video_chat_controller"

// Register controllers with Stimulus
application.register("fenetre--video-chat", VideoChatController)