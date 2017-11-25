class HomeController < ApplicationController

  # GET /
  # This renders either the polymer layout if the user is logged in OR the public website
  def root
    if current_user
      redirect_to '/home'
    else
      respond_to do |format|
        format.html { render_polymer_website }
        format.any do
          # This prevents an exception from occuring when random search engines try querying
          # for other home page formats
          not_found
        end
      end
    end
  end

  # GET /home
  def root_internal
    render_polymer_app
  end
  
  # GET /w
  # This allows internal users to access the external homepage.
  def root_external
    if current_user
      render_polymer_website
    else
      # This prevents the '/w' URL from being bookmarked or used when people aren't logged in
      redirect_to '/'
    end
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

  # GET /how-it-works
  def how_it_works
    render_polymer_website
  end

  # GET /privacy-policy
  def privacy_policy
    render_polymer_website
  end

  # GET /terms-of-service
  def terms_of_service
    render_polymer_website
  end

end
