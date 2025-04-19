import "qunit"
import "@hotwired/stimulus"

// Import all test files
import "test/video_chat_controller_test"

// Setup Stimulus application for tests
const application = Stimulus.Application.start()

// Register your controllers
import VideoChatController from "controllers/fenetre/video_chat_controller"
application.register("fenetre--video-chat", VideoChatController)

// Configure QUnit
QUnit.config.autostart = true;
