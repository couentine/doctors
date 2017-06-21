# Use this hook to configure devise mailer, warden hooks and so forth.
# Many of these configuration options can be set straight in your model.
Devise.setup do |config|
  # The secret key used by Devise. Devise uses this key to generate
  # random tokens. Changing this key will render invalid all existing
  # confirmation, reset password and unlock tokens in the database.
  config.secret_key = '9cb90560a73fba25cc6510ed59941a9048a59063698a8c98e4424d76dc2228fdf51245af7d36ef331d3122db34f90721f3f46ef016fa0d7fe20ee1760193a57e'

  # ==> Mailer Configuration
  config.mailer_sender = ENV['from_email']

  # ==> ORM configuration
  require 'devise/orm/mongoid'

  config.case_insensitive_keys = [ :email ]
  config.strip_whitespace_keys = [ :email ]

  # By default Devise will store the user in session. You can skip storage for
  # :http_auth and :token_auth by adding those symbols to the array below.
  # Notice that if you are skipping storage for all authentication paths, you
  # may want to disable generating routes to Devise's sessions controller by
  # passing :skip => :sessions to `devise_for` in your config/routes.rb
  config.skip_session_storage = [:http_auth]

  config.stretches = Rails.env.test? ? 1 : 10

  # ==> Configuration for :confirmable
  config.allow_unconfirmed_access_for = 6.days

  # If true, requires any email changes to be confirmed (exactly the same way as
  # initial account confirmation) to be applied. Requires additional unconfirmed_email
  # db field (see migrations). Until confirmed new email is stored in
  # unconfirmed email column, and copied to email column on successful confirmation.
  config.reconfirmable = true


  # ==> Configuration for :rememberable
  config.remember_for = 2.weeks

  # ==> Configuration for :validatable
  config.password_length = 6..128

  # ==> Configuration for :timeoutable
  config.timeout_in = 24.hours

  # Time interval you can reset your password with a reset password key.
  config.reset_password_within = 3.days

  # The default HTTP method used to sign out a resource. Default is :delete.
  config.sign_out_via = :delete

  Devise::Async.backend = :sidekiq
  Devise::Async.queue = :mailer

  # === OMNIAUTH SETTINGS === #

  # Google oauth (https://github.com/plataformatec/devise/wiki/OmniAuth:-Overview)
  config.omniauth :google_oauth2, 
    ENV['oauth_google_client_id'], ENV['oauth_google_client_secret'], { }

  # Canvas oauth (https://github.com/atomicjolt/omniauth-canvas)
  config.omniauth :canvas, 'canvas_key', 'canvas_secret', :setup => lambda{|env|
    request = Rack::Request.new(env)
    env['omniauth.strategy'].options[:client_options].site = env['rack.session']['oauth_site']
  }

end
