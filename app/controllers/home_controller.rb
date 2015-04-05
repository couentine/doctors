class HomeController < ApplicationController

  # GET / 
  # This renders the appropriate root layout based on whether user is signed in
  def root
    if current_user
      @user = current_user
      @groups = @user.groups.asc(:name)
      render template: 'home/root_internal'
    else
      render template: 'home/root_external', layout: 'website'
    end
  end
  
  # GET /w
  # This allows internal users to access the external homepage.
  def root_external
    render layout: 'website'
  end

end
