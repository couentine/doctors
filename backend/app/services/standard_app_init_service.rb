#==========================================================================================================================================#
# 
# STANDARD APP INITIALIZATION SERVICE
# 
# This only needs to be called when a standard app is found to not exist. It goes through the whole list of standard apps
# as defined in `/config/standard_apps.yml` and creates any which are missing from the database.
# 
#==========================================================================================================================================#

class StandardAppInitService

  #=== ATTRIBUTES ===#

  attr_accessor :standard_app_config
  attr_accessor :bl_admin_account

  #=== METHODS ===#

  def initialize
    @standard_app_config = YAML.load_file("#{Rails.root}/config/standard_apps.yml")

    # Make sure that there is a valid owner user
    @bl_admin_account = User.find(ENV['bl_admin_account_email'])
    if @bl_admin_account.blank?
      @bl_admin_account = User.new
      @bl_admin_account.name = 'Badge List Admin'
      @bl_admin_account.email = ENV['bl_admin_account_email']
      @bl_admin_account.username_with_caps = User.generate_unique_username_from(@bl_admin_account.name)
      @bl_admin_account.auto_username_needs_review = true

      @bl_admin_account.password = Devise.friendly_token(40)
      @bl_admin_account.user_defined_password = false
      
      @bl_admin_account.skip_confirmation!
      @bl_admin_account.skip_reconfirmation!
      
      @bl_admin_account.save!
    end
  end

  def perform
    @standard_app_config.each do |app_slug, app_fields|
      # NOTE: Do *not* use the `App.find` method since it will infinitely recurse!
      if App.where(slug: app_slug).first.blank?
        decorated_app = AppChangeDecorator.new(
          App.new(
            owner:          @bl_admin_account,
            review_status:  'approved',
            
            name:           app_fields['name'],
            slug:           app_slug,
            type:           app_fields['type'],
            summary:        app_fields['summary'],
            description:    app_fields['description'],
            organization:   app_fields['organization'],
            website:        app_fields['website'],
            email:          app_fields['email'],
            new_image_url:  app_fields['image_url'],
          )
        )

        decorated_app.save_as(@bl_admin_account)
      end
    end
  end

end