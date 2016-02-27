source 'https://rubygems.org'
ruby '2.1.2'

#=== CORE GEMS ===#

  gem 'rails', '4.2.5'
  gem 'puma', '~> 2.15'

#=== STORAGE, MODELS & QUEUEING ===#

  gem 'mongoid', '~> 5.0'
  gem 'redis', '~> 3.2.2'
  gem 'sidekiq', '~> 4.0'
  gem 'sinatra', :require => nil
  gem 'carrierwave-mongoid', :require => 'carrierwave/mongoid'
  gem 'carrierwave_direct'
  gem 'fog'
  gem 'mini_magick', '~> 4.3.6'
  gem 'devise', '~> 3.5'
  gem 'devise-async'

#=== FRONT-END ===#
  
  gem 'sprockets-rails', '~> 3.0.1'
  gem 'sass-rails', '~> 5.0'
  gem 'coffee-rails', '~> 4.1'
  gem 'uglifier', '~> 2.7'
  gem 'jquery-rails', '~> 4.1'
  gem 'bootstrap-sass', '2.3.2.2'
  gem 'simple_form', '~> 3.2'
  gem 'kaminari', '~> 0.16.3'
  gem 'kaminari-bootstrap', '~> 0.1.3'
  gem 'polymer-rails', '~> 1.2.4'
  # gem 'polymer-elements-rails', '~> 1.0.1'
  # gem 'polymer-elements-rails', github: 'badgelist/polymer-elements-rails'
  gem 'polymer-elements-rails', github: 'badgelist/polymer-elements-rails', \
    branch: '2015-02-element-update'
  gem 'rack-cors', :require => 'rack/cors'

#=== ERRORS & DEBUGGING ===#

  gem 'rack-timeout'
  gem 'browser_details'
  gem 'exception_notification'

#=== EXTERNAL WEB SERVICES ===#

  gem 'stripe', '~> 1.33'
  gem 'intercom', '~> 3.0'
  gem 'intercom-rails'
  gem 'postmark-rails', '~> 0.5'
  gem 'twitter'
  gem 'embedly'

#=== DEVELOPMENT / TEST ===#

  group :development, :test do
    gem 'rspec-rails', '~> 3.4'
    gem 'better_errors', '~> 2.1'
    gem 'binding_of_caller'
    gem 'rack-mini-profiler'
    gem 'ultrahook'
    gem 'byebug'
  end

  group :test do
    gem 'faker'
    gem 'capybara'
    gem 'factory_girl_rails', '~> 4.0'
  end

  group :production do
    gem 'rails_12factor', '~> 0.0.3'
    gem 'newrelic_rpm'
  end
