class UsersController < ApplicationController
  
  before_filter :authenticate_user!, only: [:index]
  before_filter :badge_list_admin, only: [:index]

  # GET /a/users
  # GET /a/users.json
  # Accepts page parameters: page, page_size, sort_by, sort_order, exclude_flags[]
  def index
    # Grab the current page of users
    @page = params[:page] || 1
    @page_size = params[:page_size] || APP_CONFIG['page_size_normal']
    @exclude_flags = params[:exclude_flags] || %w(sample_data internal-data)
    @sort_by = params[:sort_by] || "name"
    @sort_order = params[:sort_order] || "asc"
    @users = User.where(:flags.nin => @exclude_flags).order_by("#{@sort_by} #{@sort_order}")\
      .page(@page).per(@page_size)

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @users }
    end
  end


  # GET /u/username
  # GET /u/username.json
  # Accepts page parameters: page, page_size
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

private

  def badge_list_admin
    unless current_user && current_user.admin?
      redirect_to '/'
    end  
  end

end