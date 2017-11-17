# Load the rails application
require File.expand_path('../application', __FILE__)

# Neccessary to enable verification of LTI signatures with the OAuth gem
require 'oauth/request_proxy/rack_request'

# Initialize the rails application
BadgeList::Application.initialize!

# Add custom date & time formats
Time::DATE_FORMATS[:short_date] = "%-m/%-d/%y"
Time::DATE_FORMATS[:full_date] = "%B %-d, %Y"
Time::DATE_FORMATS[:short_date_time] = "%-m/%-d/%y at %l:%M%P"
Time::DATE_FORMATS[:full_date_time] = "%B %-d, %Y at %l:%M %p"
Time::DATE_FORMATS[:year_month] = "%Y-%m"

# The date before which someone is considered an old fart
BL_LAUNCH_DATE = '2014-04-01'.to_date

# Initialize the constants which are used to pass the hashed asset paths to the polymer front end

if Rails.env.production?
  ASSET_PATHS = Rails.application.assets_manifest
else
  # In development this is a little trickier since the manifest isn't built yet
  ASSET_PATHS = {}
  sprockets_environment = Rails.application.assets

  Dir.glob("#{Rails.root.join('app', 'assets', 'images')}/**/*.*").map do |path| 
    path.sub("#{Rails.root.join('app', 'assets', 'images')}/", '')
  end.each do |asset_key|
    ASSET_PATHS[asset_key] = sprockets_environment.find_asset(asset_key).digest_path
  end
end

if ENV['cdn_asset_host']
  ASSET_BASE_URL = "https://#{ENV['cdn_asset_host']}/assets/"
else
  ASSET_BASE_URL = "#{ENV['root_url']}/assets/"
end