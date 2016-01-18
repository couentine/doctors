class HomeController < ApplicationController

  # GET / 
  # This renders the appropriate root layout based on whether user is signed in
  def root
    if current_user
      @user = current_user
      @groups = @user.groups(false).asc(:name)
      
      @badge_count = @user.expert_badge_ids.count
      if @badge_count >= 100
        @badge_count_digit_class = 'triple-digit'
      elsif @badge_count >= 10
        @badge_count_digit_class = 'double-digit'
      else
        @badge_count_digit_class = 'single-digit'
      end

      render template: 'home/root_internal', layout: 'app'
    else
      render template: 'home/root_external', layout: 'website'
    end
  end
  
  # GET /w
  # This allows internal users to access the external homepage.
  def root_external
    render layout: 'website'
  end

  # GET /pricing
  def pricing
    # Update analytics if logged in
    if current_user
      IntercomEventWorker.perform_async({
        'event_name' => 'viewed-pricing',
        'email' => current_user.email,
        'created_at' => Time.now.to_i
      })
    end

    render layout: 'website'
  end

  # GET /pricing_k12
  def pricing_k12
    redirect_to '/pricing#k12'
  end

  # GET /privacy-policy
  def privacy_policy
    render layout: 'website'
  end

  # GET /terms-of-service
  def terms_of_service
    render layout: 'website'
  end

  # GET /help
  def help
    # render help.html.erb
  end

end
