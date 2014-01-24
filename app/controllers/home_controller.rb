class HomeController < ApplicationController

  before_filter :authenticate_user!  

  # GET /
  # This is the root page for a signed in user
  def show
    @user = current_user
    @this_is_current_user = true
    @group_and_log_list = @user.group_and_log_list @user
  end

end
