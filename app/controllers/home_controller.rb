class HomeController < ApplicationController

  before_filter :authenticate_user!  

  # GET /
  # This is the root page for a signed in user
  def show
    @user = current_user
    @groups = @user.groups.asc(:name)
  end

end
