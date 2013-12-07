class HomeController < ApplicationController

  before_filter :authenticate_user!  

  # GET /
  # This is the root page for a signed in user
  def show
    @group_list = current_user.group_list
  end

end
