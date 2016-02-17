# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment',  __FILE__)
run BadgeList::Application

require 'rack/cors'
# Configure CORS to allow for serving of javascript and font assets from CloudFront
use Rack::Cors do
  allow do
    origins 'http://localhost', '127.0.0.1', 'http://bl-staging-mango.herokuapp.com', \
      'www.badgelist.com', 'badgelist.com'

    resource '/assets/*',
      headers: :any,
      methods: [:get, :head, :options],
      max_age: 3628800
  end
end