// This serves as an entry point for Fenetre JavaScript
// It's meant to be pinned in the importmap for use by the host application

// Re-export the main fenetre module
import "./fenetre.js"

// Load the controllers entrypoint using a relative path
import "./controllers/index.js"

// Export a basic API for the host application to use
export const Fenetre = {
  version: "1.0.0",
  // Add more public API methods as needed
}