BadgeList::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin


  # Do not compress assets
  config.assets.compress = false

  # Expands the lines which load the assets
  config.assets.debug = true

  # For devise
  # MOVED this next line to application.rb, it uses an ENV variable now
  # config.action_mailer.default_url_options = { :host => 'localhost:3000' }

  # Send email through gmail for this environment
  # if ENV['disable_all_emails']
    # Turn off emails if needed
    # config.action_mailer.delivery_method = :test
    # config.action_mailer.delivery_method = :smtp
  # else
    config.action_mailer.delivery_method = :smtp
  # end
  config.action_mailer.smtp_settings = {
    address:              'smtp.gmail.com',
    port:                 587,
    user_name:            'knowledgestreem@gmail.com',
    password:             'educ8every1!',
    authentication:       'plain',
    enable_starttls_auto: true  }

  config.log_level = :debug

end
