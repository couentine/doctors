require File.expand_path('../boot', __FILE__)

require 'csv'

# Pick the frameworks you want:
# require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "active_resource/railtie"
require "sprockets/railtie"
require "rails/test_unit/railtie"
require 'redis'

Bundler.require(:default, Rails.env)

require_relative '../app/middleware/throttle_cache.rb'
require_relative '../app/middleware/throttle_daily_with_client_id.rb'
# require_relative '../app/middleware/throttle_second_with_client_id.rb'

module BadgeList
  class Application < Rails::Application
    # Enable site-wide CORS for all origins
    config.middleware.insert_before 0, "Rack::Cors" do
      allow do
        origins '*'
        resource '*', headers: :any, methods: :any
      end
    end
    
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W(#{config.root}/lib/modules #{config.root}/app)

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'Pacific Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de
    config.i18n.enforce_available_locales = false

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Enable escaping HTML in JSON.
    config.active_support.escape_html_entities_in_json = true

    # Use SQL instead of Active Record's schema dumper when creating the database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    # config.active_record.schema_format = :sql

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '2.0'

    # For devise
    config.assets.initialize_on_precompile = false
    config.action_mailer.default_url_options = { :host => ENV['root_domain'] }
    config.to_prepare do
      # Tell devise emails to use the standard email layout
      Devise::Mailer.layout 'email_standard'
    end

    config.assets.precompile += %w( rich-text-editor.css )

    # Override security defaults
    config.action_dispatch.default_headers = {
      'X-Frame-Options' => 'ALLOWALL',
      'X-XSS-Protection' => '1; mode=block',
      'X-Content-Type-Options' => 'nosniff'
    }

    # Enable rate-throttling via the `rack-throttle` gem, utilizing redis as the cache
    config.middleware.use Rack::Throttle::DailyWithClientId, cache: ThrottleCache.new, max: (ENV['max_requests_per_day'] || 100000)
    # config.middleware.use Rack::Throttle::SecondWithClientId, cache: ThrottleCache.new, max: (ENV['max_requests_per_second'] || 10)
    # >> Disabling per-second throttling for now. This will end up breaking some of the page loads.

  end
end