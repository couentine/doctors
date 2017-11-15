class ApplicationController < ActionController::Base
  layout 'legacy' # Default to legacy layout for now
  protect_from_forgery
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :log_activity
  before_action :set_app_variables
  after_action :store_location

  # unless Rails.application.config.consider_all_requests_local
    # rescue_from Exception, with: :render_500
    rescue_from ActionController::RoutingError, with: :render_404
    rescue_from ActionController::UnknownController, with: :render_404
    # rescue_from ActionController::UnknownAction, with: :render_404
    rescue_from Mongoid::Errors::DocumentNotFound, with: :render_404
  # end

  def not_found
    raise ActionController::RoutingError.new('Not Found')
  end

  def render_404(exception)
    @not_found_path = exception.message
    respond_to do |format|
      format.html { render template: 'errors/not_found', layout: 'layouts/legacy', 
        status: 404 }
      format.all { render nothing: true, status: 404 }
    end
  end
 
  def render_500(exception)
    logger.info exception.backtrace.join("\n")
    @error_message = exception.backtrace.join("\n")
    respond_to do |format|
      format.html { render template: 'errors/internal_server_error', layout: 'layouts/legacy', 
        status: 500 }
      format.all { render nothing: true, status: 500}
    end
  end

  def store_location
    if ((request.format == "text/html") || (request.content_type == "text/html"))
      # Store the last url as long as it isn't a /users path
      # This is used by the signin controller to return to same page after signin
      if !(request.fullpath =~ /\/users/) && !(request.fullpath =~ /\/j\/image_key/)
        session[:previous_path] = request.fullpath
      end

      if !params[:join].blank?
        # If the 'join' parameter is set then store the badge id
        session[:join_badge_id] = params[:join]
      elsif !params[:join_group].blank?
        session[:join_group_id] = params[:join_group]
        session[:join_group_code] = params[:join_group_code]
      elsif !params[:plan].blank? && !current_user
        # Save the group plan param if supplied
        session[:new_group_plan] = params[:plan]
      end
    end
  end

  def after_sign_in_path_for(resource)
    if !session[:join_badge_id].blank?
      badge = Badge.find(session[:join_badge_id]) rescue nil
    elsif !session[:join_group_id].blank?
      group = Group.find(session[:join_group_id]) rescue nil
    end

    if badge
      "/#{badge.group.url}/#{badge.url}/join"
    elsif group
      if session[:join_group_code]
        "/#{group.url}/join?code=#{session[:join_group_code]}"
      else
        "/#{group.url}/join"
      end
    elsif session[:user_return_to] == "/users/edit?d=ac"
      "/users/edit#add-card"
    elsif session[:user_return_to] == "/users/edit"
      "/users/edit"
    elsif session[:new_group_plan]
      "/groups/new?plan=#{session[:new_group_plan]}"
    else
      session[:previous_path] || root_path
    end
  end

  # Call this from controller actions which use the polymer app frontend.
  # It sets the needed manifest variable and renders the polymer layout.
  def render_polymer_app
    @manifest = {
      app_root_url: ENV['root_url'],
      polymer_root_url: @polymer_app_root_url,
      csrf_token: form_authenticity_token,
      current_user: (current_user.present?) ? current_user.json(:current_user) : nil
    }
    
    render template: 'polymer/app', layout: 'polymer_app'
  end

  # Call this from controller actions which use the polymer website frontend.
  # It sets the needed manifest variable and renders the polymer layout.
  def render_polymer_website
    @manifest = {
      app_root_url: ENV['root_url'],
      polymer_root_url: @polymer_website_root_url,
      csrf_token: form_authenticity_token,
      current_user: (current_user.present?) ? current_user.json(:current_user) : nil
    }
    
    render template: 'polymer/website', layout: 'polymer_website'
  end

private

  def log_activity
    current_user.log_activity if current_user
  end

  def set_app_variables
    # Set the current user json var
    @current_user_json = (current_user) ? current_user.json(:current_user).to_json : '{}'

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

    # Set the root url of the polymer server (in dev) or the polymer asset folder (in production)
    if Rails.env.production?
      @polymer_app_root_url = "#{ENV['root_url']}/p/app"
      @polymer_website_root_url = "#{ENV['root_url']}/p/website"
    else
      # We're using the polymer-proxy server (on port 8100) to add CORS headers to responses from the polymer app server (on port 8500)
      @polymer_app_root_url = 'http://localhost:8100/0.0.0.0:8500'

      # We're using the polymer-proxy server (on port 8100) to add CORS headers to responses from the polymer website server (on port 8510)
      @polymer_website_root_url = 'http://localhost:8100/0.0.0.0:8510'
    end
  end

protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.for(:sign_up) do |u| 
      u.permit(:name, :username_with_caps, :avatar_key, :email, :password, :password_confirmation, 
        :remember_me, :job_title, :organization_name, :website, :bio) 
    end

    devise_parameter_sanitizer.for(:sign_in) do |u| 
      u.permit(:email, :password, :remember_me) 
    end

    devise_parameter_sanitizer.for(:account_update) do |u| 
      u.permit(:name, :username_with_caps, :avatar_key, :email, :password, :password_confirmation, 
        :current_password, :job_title, :organization_name, :website, :bio) 
    end
  end

end