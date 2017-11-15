# This is the development procfile

web: cd backend && bundle exec puma -C config/puma.rb
worker: cd backend && bundle exec sidekiq
polymer-app: cd frontend/app && polymer serve -p 8500
polymer-website: cd frontend/website && polymer serve -p 8510
polymer-proxy: cd dev/polymer-proxy && npm start