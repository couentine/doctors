class ApplicationController < ActionController::Base
  protect_from_forgery
  before_filter :log_activity
  after_filter :store_location

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
      format.html { render template: 'errors/not_found', layout: 'layouts/application', 
        status: 404 }
      format.all { render nothing: true, status: 404 }
    end
  end
 
  def render_500(exception)
    logger.info exception.backtrace.join("\n")
    @error_message = exception.backtrace.join("\n")
    respond_to do |format|
      format.html { render template: 'errors/internal_server_error', layout: 'layouts/application', 
        status: 500 }
      format.all { render nothing: true, status: 500}
    end
  end

  def store_location
    if ((request.format == "text/html") || (request.content_type == "text/html"))
      # Store the last url as long as it isn't a /users path
      session[:previous_url] = request.fullpath unless request.fullpath =~ /\/users/

      if !params[:join].blank?
        # If the 'join' parameter is set then store the badge id
        session[:join_badge_id] = params[:join]
      elsif !params[:plan].blank? && !current_user
        # Save the group plan param if supplied
        session[:new_group_plan] = params[:plan]
      end
    end
  end

  def after_sign_in_path_for(resource)
    if !session[:join_badge_id].blank?
      badge = Badge.find(session[:join_badge_id]) rescue nil
    end

    if badge
      "/#{badge.group.url}/#{badge.url}/join"
    elsif session[:user_return_to] == "/users/edit?d=ac"
      "/users/edit#add-card"
    elsif session[:user_return_to] == "/users/edit"
      "/users/edit"
    elsif session[:new_group_plan]
      "/groups/new?plan=#{session[:new_group_plan]}"
    else
      session[:previous_url] || root_path
    end
  end

private

  def log_activity
    current_user.log_activity if current_user
  end

end
