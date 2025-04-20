# frozen_string_literal: true

# Ensure JavaScript files are served with the correct MIME type
# This is especially important for the test environment

# First, make sure the standard MIME type is registered globally
Mime::Type.register 'application/javascript', :js, %w[application/javascript text/javascript]

# Custom middleware to set the proper content type for JavaScript files
class JavascriptMimeTypeMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)
    
    # Check if the request is for a JavaScript file
    if env['PATH_INFO'] =~ /\.js$/
      # Set the correct MIME type for JavaScript files
      headers['Content-Type'] = 'application/javascript'
    end
    
    [status, headers, response]
  end
end

# Add our custom middleware to ensure JavaScript files get the right MIME type
Rails.application.config.middleware.use JavascriptMimeTypeMiddleware