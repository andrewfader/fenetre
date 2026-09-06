# frozen_string_literal: true

require_relative 'lib/fenetre/version'

Gem::Specification.new do |spec|
  spec.name        = 'fenetre'
  spec.version     = Fenetre::VERSION
  spec.authors     = ['Andrew Fader']
  spec.email       = ['fader@yagni.co']
  spec.homepage    = 'https://github.com/andrewfader/fenetre'
  spec.summary     = 'WebRTC video chat with Action Cable and Stimulus for Rails.'
  spec.description = 'Provides components and controllers for building real-time video chat features in Rails applications using WebRTC, Action Cable, Turbo Streams, and Stimulus.'
  spec.license     = 'MIT'
  # Supported: the latest minor of each supported Ruby major (3.4.x and 4.0.x).
  spec.required_ruby_version = ['>= 3.4', '< 5']

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,lib}/**/*', 'LICENSE.txt', 'README.md'].select { |path| File.file?(path) }
  end

  spec.add_dependency 'importmap-rails'
  spec.add_dependency 'propshaft'
  spec.add_dependency 'rails', '>= 7.1', '< 9'
  spec.add_dependency 'stimulus-rails'
  spec.add_dependency 'turbo-rails'

  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'nokogiri' # For parsing HTML in helper tests
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'redis', '>= 4.0' # For dummy app Action Cable
  # Core dependencies for the dummy Rails app itself
  spec.add_development_dependency 'parallel_tests'
  spec.add_development_dependency 'puma', '>= 5.0'
  spec.add_development_dependency 'sqlite3', '>= 1.4' # Use version compatible with Rails 6.1+
  spec.metadata['rubygems_mfa_required'] = 'true'
end
