BadgeList::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # Code is not reloaded between requests
  config.cache_classes = true

  config.eager_load = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # We need to turn this on so that we serve the polymer frontend on heroku
  # UPDATE ==> Setting this to false for now
  config.serve_static_files = false

  # Compress JavaScripts and CSS
  config.assets.js_compressor = :uglifier

  # Don't fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = false

  # Generate digests for assets URLs
  config.assets.digest = true

  # Defaults to nil and saved in location specified by config.assets.prefix
  # config.assets.manifest = YOUR_PATH

  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # See everything in the log (default is :info)
  config.log_level = :info

  # Prepend all log lines with the following tags
  # config.log_tags = [ :subdomain, :uuid ]

  # Use a different logger for distributed setups
  # config.logger = ActiveSupport::TaggedLogging.new(SyslogLogger.new)

  # Use a different cache store in production
  # config.cache_store = :mem_cache_store

  # Enable serving of images, stylesheets, and JavaScripts from an asset server
  config.action_controller.asset_host = ENV['cdn_asset_host'] || 'cdn.badgelist.com'
  config.action_mailer.asset_host = ENV['cdn_asset_host'] || 'cdn.badgelist.com'

  # Precompile additional assets
  # config.assets.precompile =  ['*.js', '*.css', '*.css.erb'] 

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false

  # Enable threaded mode
  # config.threadsafe!

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  # For devise
  # MOVED this next line to application.rb, it uses an ENV variable now
  # config.action_mailer.default_url_options = { :host => 'badgelist.com' }

  # Configure postmark gem (for email delivery)
  config.action_mailer.delivery_method = :postmark
  config.action_mailer.postmark_settings = { :api_key => ENV['POSTMARK_API_KEY'] }

  # Exception notification gem
  config.middleware.use ExceptionNotification::Rack,
    :email => {
      :email_prefix => "[BLA] ",
      :sender_address => %{Badge List Alerts <#{ENV['from_email']}>},
      :exception_recipients => %w{app-errors@badgelist.com}
    }

end