# frozen_string_literal: true

# Pins provided by the fenetre gem for use in the host app's importmap.rb
# Only pin what the gem provides; do not pin host app or external dependencies

# Pin the main fenetre module
pin 'fenetre', to: 'fenetre.js'
pin 'fenetre/application', to: 'fenetre/application.js'
pin 'fenetre/import_map_resolver', to: 'fenetre/import_map_resolver.js', preload: true

# Pin controllers
pin_all_from 'fenetre/controllers', under: 'controllers/fenetre'

# Add application mapping for host apps to use (typically a re-export)
pin 'application', to: 'fenetre/application.js'

# Add Stimulus dependency mapping
pin '@hotwired/stimulus', to: 'stimulus/stimulus.min.js'
