# frozen_string_literal: true

require_relative 'lib/fenetre/version'

Gem::Specification.new do |spec|
  spec.name        = 'fenetre'
  spec.version     = Fenetre::VERSION
  spec.authors     = ['Andrew Fader'] # TODO: Update with your name
  spec.email       = ['fader@yagni.co'] # TODO: Update with your email
  spec.homepage    = 'https://github.com/andrewfader/fenetre' # TODO: Update with your repo URL
  spec.summary     = 'WebRTC video chat with Turbo Streams and Stimulus for Rails.'
  spec.description = 'Provides components and controllers for building real-time video chat features in Rails applications using WebRTC, Action Cable, Turbo Streams, and Stimulus.'
  spec.license     = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata['allowed_push_host'] = 'TODO: Set to your gem server host'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  end

  spec.add_dependency 'rails', '>= 6.1' # Adjust Rails version as needed
  spec.add_dependency 'stimulus-rails'
  spec.add_dependency 'turbo-rails'

  spec.add_development_dependency 'importmap-rails' # For dummy app JS
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'nokogiri' # For parsing HTML in helper tests
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'redis', '>= 4.0' # For dummy app Action Cable
  # Core dependencies for the dummy Rails app itself
  spec.add_development_dependency 'propshaft'
  spec.add_development_dependency 'puma', '>= 5.0'
  spec.add_development_dependency 'sqlite3', '>= 1.4' # Use version compatible with Rails 6.1+
  spec.add_development_dependency "actioncable", ">= 8.0"
  spec.add_development_dependency "turbo-rails"
  spec.add_development_dependency "stimulus-rails"
end
