#=== STANDARD APP RELATED CONSTANTS ===#

# This can be used to prevent deletion of the standard apps
# It is also used in the App.find method to automatically trigger the creation of the app if it doesn't exist
STANDARD_APPS = YAML.load_file("#{Rails.root}/config/standard_apps.yml").keys.freeze

# Be careful with this one. 
# First of all this must only include app slugs which are also in STANDARD_APPS.
# Second of all, any apps in this list will result in every user and group being added to them without the option of unjoining.
# That's why it's hardcoded. I can't currently imagine why we would want more of these, but I'm sure it's possible.
MANDATORY_APPS = ['badgelist'].freeze