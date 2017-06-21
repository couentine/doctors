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
