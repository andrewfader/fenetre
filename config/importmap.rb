# Pin npm packages by running ./bin/importmap

pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/turbo", to: "turbo.js", preload: true

# Pin your own JS modules
pin "application", to: "fenetre/application.js"
pin "controllers/index", to: "fenetre/controllers/index.js"
pin "controllers/fenetre/video_chat_controller", to: "fenetre/controllers/fenetre/video_chat_controller.js"