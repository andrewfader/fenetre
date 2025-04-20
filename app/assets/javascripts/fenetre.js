// Fenetre main entry point
// Handle importing and registering the video chat controller

// First check if we have a global Stimulus instance
if (window.Stimulus) {
  loadControllerWithGlobalStimulus();
} else {
  // Otherwise try to import Stimulus and initialize it
  importStimulusAndLoadController();
}

// Function to load the controller when Stimulus is already available
function loadControllerWithGlobalStimulus() {
  // Try multiple paths to import the controller
  Promise.any([
    import('./controllers/fenetre/video_chat_controller'),
    import('controllers/fenetre/video_chat_controller'),
    import('fenetre/controllers/video_chat_controller')
  ])
  .then(module => {
    window.Stimulus.register('fenetre--video-chat', module.default);
    console.log('Fenetre: Video chat controller registered with global Stimulus');
  })
  .catch(error => {
    console.error('Fenetre: Failed to load video chat controller:', error);
  });
}

// Function to import Stimulus if it's not globally available
function importStimulusAndLoadController() {
  // Try to import Stimulus with various module specifiers
  Promise.any([
    import('stimulus'),
    import('@hotwired/stimulus')
  ])
  .then(module => {
    const { Application } = module;
    window.Stimulus = Application.start();
    
    // Now load the controller
    return Promise.any([
      import('./controllers/fenetre/video_chat_controller'),
      import('controllers/fenetre/video_chat_controller'),
      import('fenetre/controllers/video_chat_controller')
    ]);
  })
  .then(module => {
    window.Stimulus.register('fenetre--video-chat', module.default);
    console.log('Fenetre: Video chat controller registered successfully');
  })
  .catch(error => {
    console.error('Fenetre: Failed to initialize Stimulus or load controller:', error);
  });
}
