class RegistrationsController < Devise::RegistrationsController
  
  # GET /users/sign_up
  def new
    # Create the carrierwave direct uploader
    @uploader = User.new.direct_avatar
    @uploader.success_action_redirect = image_key_url
    
    super
  end

  # GET /users/edit
  def edit
    # Create the carrierwave direct uploader
    @uploader = User.new.direct_avatar
    @uploader.success_action_redirect = image_key_url

    if !resource.domain_id.blank?
      # Then set the properties of the private domain label
      if resource.domain_membership == 'private'
        @domain_tooltip = 'Your account is part of a private domain and is only visible to other ' \
          + 'domain members.'
        @domain_label_icon = 'fa-eye-slash'
        @domain_label_text = 'Private Domain'
      elsif resource.domain_membership == 'private-excluded'
        @domain_tooltip = 'Your account is part of a private domain but it has been exempted from ' \
          + 'privacy.'
        @domain_label_icon = 'fa-eye'
        @domain_label_text = 'Private Domain'
      elsif resource.domain_membership == 'public'
        @domain_tooltip = 'Your account is part of a registered domain that is visible to the public.'
        @domain_label_icon = 'fa-building'
        @domain_label_text = 'Registered Domain'
      end
    end

    super
  end

  # POST /users
  def create
    # Copied from Devise source code (commit #2024fca): http://bit.ly/1d8FqHm
    # This is copied so that we add custom image upload related logic.

    build_resource(sign_up_params)

    resource.save
    yield resource if block_given?
    if resource.persisted?
      if resource.active_for_authentication?
        set_flash_message :notice, :signed_up if is_flashing_format?
        sign_up(resource_name, resource)
        respond_with resource, location: after_sign_up_path_for(resource)
      else
        set_flash_message :notice, :"signed_up_but_#{resource.inactive_message}" if is_flashing_format?
        expire_data_after_sign_in!
        respond_with resource, location: after_inactive_sign_up_path_for(resource)
      end
    else
      # Create the carrierwave direct uploader
      @uploader = resource.direct_avatar
      @uploader.success_action_redirect = image_key_url
      @manual_user_image_path = "#{ENV['s3_asset_url']}/#{ENV['s3_bucket_name']}/" \
        + resource.direct_avatar.key

      clean_up_passwords resource
      # set_minimum_password_length # >> Triggers an error, ignoring for now.
      respond_with resource
    end
  end

  # PUT /users
  def update
    # Create the carrierwave direct uploader
    @uploader = User.new.direct_avatar
    @uploader.success_action_redirect = image_key_url

    super
  end

end 