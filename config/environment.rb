# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
BadgeList::Application.initialize!

# Add custom date & time formats
Time::DATE_FORMATS[:short_date] = "%-m/%-d/%y"
Time::DATE_FORMATS[:full_date] = "%B %-d, %Y"
Time::DATE_FORMATS[:short_date_time] = "%-m/%-d/%y at %l:%M%P"
Time::DATE_FORMATS[:full_date_time] = "%B %-d, %Y at %l:%M %p"