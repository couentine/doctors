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
  ASSET_PATHS = Rails.application.assets_manifest.assets
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

# Now make the json version of the asset paths
JSON_ASSET_PATHS = {}
ASSET_PATHS.each do |key, value|
  current_hash = JSON_ASSET_PATHS
  
  if key.include?('/')
    path_items = key.split('/')
    pathless_key = path_items.last
    path_items.first(path_items.count - 1).each do |path_item|
      camelized_path_item = path_item.gsub(/[-\.\/]/, '_').camelize(:lower)
      current_hash[camelized_path_item] = {} if !current_hash.has_key?(camelized_path_item)
      current_hash = current_hash[camelized_path_item]
    end
  else
    pathless_key = key
  end

  current_hash[pathless_key.gsub(/[-\.\/]/, '_').camelize(:lower)] = ASSET_BASE_URL + value
end

# NOTE: The polymer website and app only have a subset of the total assets available. Root-level assets are not included, only the items
# in the specified sub-folder of the assets folder are available.
website_asset_folders = ['icons', 'graphics', 'brand', 'customers', 'backgrounds']
app_asset_folders = ['brand', 'backgrounds']

POLYMER_WEBSITE_ASSETS = JSON_ASSET_PATHS.select{|key, value| website_asset_folders.include? key }
POLYMER_APP_ASSETS = JSON_ASSET_PATHS.select{|key, value| app_asset_folders.include? key }