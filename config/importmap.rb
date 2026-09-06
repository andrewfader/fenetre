# frozen_string_literal: true

# Engine defaults are drawn before the host application's pins.
pin '@hotwired/stimulus', to: 'stimulus.min.js'
pin '@rails/actioncable', to: 'actioncable.esm.js'
pin 'fenetre', to: 'fenetre.js'
pin 'fenetre/application', to: 'fenetre/application.js'
pin 'fenetre/controllers', to: 'fenetre/controllers/index.js'
pin 'fenetre/controllers/video_chat_controller', to: 'fenetre/controllers/video_chat_controller.js'
pin 'controllers/fenetre/video_chat_controller', to: 'fenetre/controllers/video_chat_controller.js'
