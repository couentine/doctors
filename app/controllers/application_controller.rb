class ApplicationController < ActionController::Base
  protect_from_forgery
  before_filter :track_page_views
  after_filter :store_location

  # unless Rails.application.config.consider_all_requests_local
    # rescue_from Exception, with: :render_500
    rescue_from ActionController::RoutingError, with: :render_404
    rescue_from ActionController::UnknownController, with: :render_404
    rescue_from ActionController::UnknownAction, with: :render_404
    rescue_from Mongoid::Errors::DocumentNotFound, with: :render_404
  # end

  def not_found
    raise ActionController::RoutingError.new('Not Found')
  end

  def render_404(exception)
    @not_found_path = exception.message
    respond_to do |format|
      format.html { render template: 'errors/not_found', layout: 'layouts/application', status: 404 }
      format.all { render nothing: true, status: 404 }
    end
  end
 
  def render_500(exception)
    logger.info exception.backtrace.join("\n")
    @error_message = exception.backtrace.join("\n")
    respond_to do |format|
      format.html { render template: 'errors/internal_server_error', layout: 'layouts/application', status: 500 }
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
      elsif !params[:create_k12].blank?
        # If they hit the registration page with the create_k12 param set then store it for later
        session[:create_k12] = true
      end
    end
  end

  def after_sign_in_path_for(resource)
    if !session[:join_badge_id].blank?
      badge = Badge.find(session[:join_badge_id]) rescue nil
    end

    if badge
      "/#{badge.group.url}/#{badge.url}/join"
    elsif session[:create_k12]
      "/groups/new?pg=k12"
    elsif session[:user_return_to] == "/users/edit?d=ac"
      "/users/edit#add-card"
    else
      session[:previous_url] || root_path
    end
  end

private

  # This updates the page_views and last_active_at fields on the current_user (if logged in)
  # and also sets the @page_view_count & @current_path variables
  def track_page_views
    @current_path = request.fullpath.split('?').first
    
    unless @current_path.include?(".") # this discludes .json, .png AND anything with a dot in it
      if current_user
        # First update the page views
        current_user.page_views = [] if current_user.page_views.nil?
        current_item = current_user.page_views[@current_path]

        if current_item.nil?
          @page_view_count = 0
          current_item = { 'count' => 1, 'dates' => [Time.now] }
          current_user.page_views[@current_path] = current_item
        else
          @page_view_count = current_item['count'] || 0
          current_item['count'] = @page_view_count + 1
          if current_item['dates'].nil?
            current_item['dates'] = [Time.now]
          else
            current_item['dates'] << Time.now
          end
          current_user.page_views[@current_path] = current_item
        end

        # Then update the last active fields
        current_user.last_active_at = Time.now
        current_user.active_months = [] if current_user.active_months.nil?
        if current_user.active_months.empty?
          current_user.active_months = [Time.now.to_s(:year_month)]
        elsif current_user.active_months.last != Time.now.to_s(:year_month)
          current_user.active_months << Time.now.to_s(:year_month)
        end


        # Now update the user record
        current_user.timeless.save if current_user.changed?
      else
        @page_view_count = 0
      end
    else
      @page_view_count = 0
    end
  end

end
