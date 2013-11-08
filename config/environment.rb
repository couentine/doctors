# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
BadgeList::Application.initialize!

# Add custom date & time formats
Time::DATE_FORMATS[:full_date] = "%B %-d, %Y"