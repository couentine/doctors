class HomeController < ApplicationController

  # GET / 
  # This redirects to the appropriate root page based on whether user is signed in
  def root
    if current_user
      redirect_to :root_internal
    else
      redirect_to :root_external
    end
  end
  
  # GET / (if logged in)
  # This is the root page for a signed in user
  def root_internal
    @user = current_user
    @groups = @user.groups.asc(:name)
  end
  
  # GET / (if not logged in)
  # This is the root page for a signed in user
  def root_external
    render layout: 'website'
  end

end
