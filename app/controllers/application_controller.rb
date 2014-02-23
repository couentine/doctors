class ApplicationController < ActionController::Base
  protect_from_forgery
  before_filter :track_page_views

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

private

  # This updates the page_views field on the current_user (if logged in)
  # and also sets the @page_view_count & @current_path variables
  def track_page_views
    @current_path = request.fullpath.split('?').first
    
    unless @current_path.include?(".png") || @current_path.include?(".json")
      if current_user
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

        current_user.timeless.save if current_user.changed?
      else
        @page_view_count = 0
      end
    else
      @page_view_count = 0
    end
  end

end
