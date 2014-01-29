class UsersController < ApplicationController
  
  # Accepts page parameters: page, page_size
  # GET /u/username
  # GET /u/username.json
  def show
    @user = User.find(params[:id]) || not_found
    @group_and_log_list = @user.group_and_log_list current_user
    @this_is_current_user = current_user && (@user == current_user)

    # Grab the current page of entries
    @page = params[:page] || 1
    @page_size = params[:page_size] || APP_CONFIG['page_size_normal']
    @entries = @user.entries(current_user, @page, @page_size)

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @user }
    end
  end

end