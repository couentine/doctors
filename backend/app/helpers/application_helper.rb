module ApplicationHelper

  # Returns the full title on a per-page basis.
  def full_title(page_title)
    base_title = "Badge List"
    if page_title.empty?
      base_title
    else
      "#{page_title} - #{base_title}"
    end
  end

  # Turns booleans into on of two strings
  # Useful for showing or hiding elements conditionally
  # In it's default form you can think of it as saying 'display if ______'
  def d?(boolean_value, true_string = '', false_string = 'display: none;')
    (boolean_value) ? true_string : false_string
  end

  def set_app_variables
    # Set the current user json var
    @current_user_json = (current_user.present?) ? current_user.json(:current_user).to_json : '{}'
    @current_user_gtm_json = (current_user.present?) ? current_user.json(:google_tag_manager).to_json : '{}'

    # The @asset_paths variable is passed into bl-app-container.assetPaths and is used to provide
    # the paths of the various asset paths to the Polymer front end.
    url = ActionController::Base.helpers
    url.request = request
    @asset_paths = {
      'rootURL' => ENV['root_url'],
      'badgeListShieldSquare' \
        => url.asset_url('badge-list-shield-square.png'),
      'badgeListShieldWhiteSquare' \
        => url.asset_url('badge-list-shield-white-square.png')
    }
    @ap_json = @asset_paths.to_json

    # Set the root urls of the polymer servers
    @polymer_app_root_url = "#{ENV['root_url']}/p/app"
    @polymer_website_root_url = "#{ENV['root_url']}/p/website"

    # Determine the user's persona and calculate the intercom settings
    @current_user_persona = 'visitor'
    if current_user.present?
      if current_user.admin?
        @current_user_persona = 'internal'
      elsif current_user.admin_of_ids.present?
        @current_user_persona = 'admin'
      elsif current_user.expert_badge_ids.present?
        @current_user_persona = 'holder'
      elsif current_user.learner_badge_ids.present?
        @current_user_persona = 'seeker'
      else
        @current_user_persona = 'user'
      end

      @intercom_settings = {
        app_id: ENV['INTERCOM_APP_ID'],
        user_hash: OpenSSL::HMAC.hexdigest('sha256', ENV['INTERCOM_USER_HASH_SECRET_KEY'], current_user.id.to_s),
        persona: @current_user_persona
      }.merge(current_user.json(:intercom_user))
          
      if @group && current_user.admin_of?(@group)
        @intercom_settings.merge!({
          company: @group.json(:intercom_company)
        })
      end
    else
      @intercom_settings = {
        app_id: ENV['INTERCOM_APP_ID']
      }
    end
  end

end
