// Fenetre main entry point - Fallback approach for reliable operation
// This version avoids import statements entirely for maximum compatibility

// Dynamically load the import map resolver first
// This must be at the top to ensure it resolves bare specifiers before other modules load
document.addEventListener('DOMContentLoaded', function() {
  const script = document.createElement('script');
  // Determine base path from current fenetre.js script
  const currentSrc = (document.currentScript && document.currentScript.src) ||
                     document.querySelector('script[src*="fenetre"]')?.src;
  if (currentSrc) {
    // Replace fenetre(-hash).js with fenetre/import_map_resolver.js
    const resolverPath = currentSrc.replace(/\/fenetre(-.*)?\.js$/, '/fenetre/import_map_resolver.js');
    script.src = resolverPath;
  } else {
    // Fallback to assets location
    script.src = '/assets/fenetre/import_map_resolver.js';
  }
  script.async = false;
  document.head.appendChild(script);
});

// Function to register the controller with Stimulus
function registerFenetreController() {
  // Check if the controller is already available globally
  // (This would happen if it was loaded separately via importmap)
  const controller = window.Fenetre?.Controllers?.VideoChatController;
  
  // Try multiple approaches to find Stimulus
  const stimulus = window.Stimulus || 
                   (window.stimulus && window.stimulus.application) || 
                   (window.Rails && window.Rails.stimulus);
  
  // If Stimulus is available, register our controller
  if (stimulus) {
    try {
      if (!controller) {
        console.warn("Fenetre: Controller not found via importmap. Recommend adding 'pin \"controllers/fenetre/video_chat_controller\"' to your importmap.");
        return; // Exit if controller not found
      }
      
      // Modern Rails 7+ approach
      if (stimulus.register) {
        stimulus.register("fenetre--video-chat", controller);
      } 
      // Fall back to application.register approach
      else if (stimulus.application && stimulus.application.register) {
        stimulus.application.register("fenetre--video-chat", controller);
      }
      // Legacy approach
      else if (stimulus.Application) {
        const application = stimulus.Application.start();
        application.register("fenetre--video-chat", controller);
      }
      console.log("Fenetre: Video chat controller registered successfully.");
    } catch (e) {
      console.error("Fenetre: Error registering controller:", e);
    }
  } else {
    console.error(
      "Fenetre: Stimulus not found. Ensure Stimulus is loaded in your application.js before fenetre.js."
    );
  }
}

// Register when DOM is ready
if (document.readyState === "loading") { 
  document.addEventListener("DOMContentLoaded", registerFenetreController);
} else {
  registerFenetreController();
}
