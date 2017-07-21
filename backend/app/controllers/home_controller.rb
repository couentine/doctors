class HomeController < ApplicationController

  # GET /
  # This renders either the polymer layout if the user is logged in OR the public website
  def root
    if current_user
      @manifest = {
        polymer_root_url: @polymer_root_url,
        csrf_token: form_authenticity_token,
        current_user: (current_user.present?) ? current_user.json(:current_user) : nil
      }
      
      render template: 'polymer/show', layout: 'polymer'
    else
      respond_to do |format|
        format.html { render template: 'home/root_external', layout: 'web' }
        format.any do
          # This prevents an exception from occuring when random search engines try querying
          # for other home page formats
          not_found
        end
      end
    end
  end
  
  # GET /w
  # This allows internal users to access the external homepage.
  def root_external
    if current_user
      render layout: 'web'
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
    render layout: 'web'
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
