# Pins provided by the fenetre gem for use in the host app's importmap.rb
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "application", to: "application.js"
pin_all_from "fenetre/controllers", under: "controllers/fenetre"
