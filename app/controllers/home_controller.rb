class HomeController < ApplicationController

  before_filter :authenticate_user!  

  # GET /
  # This is the root page for a signed in user
  def show
    @user = current_user
    @group_and_log_list = @user.group_and_log_list
  end

end
