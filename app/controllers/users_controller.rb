class UsersController < ApplicationController
  
  before_filter :authenticate_user!, only: [:index, :add_card, :delete_card, :payment_history]
  before_filter :badge_list_admin, only: [:index]

  # GET /a/users
  # GET /a/users.json
  # Accepts page parameters: page, page_size, sort_by, sort_order, flag
  def index
    # Grab the current page of users
    @page = params[:page] || 1
    @page_size = params[:page_size] || APP_CONFIG['page_size_normal']
    @only_flag = params[:flag]
    # @exclude_flags = params[:exclude_flags] || %w(sample_data internal-data)
    @sort_by = params[:sort_by] || "last_active"
    @sort_order = params[:sort_order] || "desc"
    
    if @only_flag
      @users = User.where(:flags.in => [@only_flag]).order_by("#{@sort_by} #{@sort_order}")\
        .page(@page).per(@page_size)
    else
      @users = User.order_by("#{@sort_by} #{@sort_order}").page(@page).per(@page_size)
    end

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @users, filter_user: current_user }
    end
  end

  # GET /u/username
  # GET /u/username.json
  # Accepts page parameters: page, page_size
  def show
    @user = User.find(params[:id]) || not_found
    @expert_group_badge_log_list = @user.expert_group_badge_log_list
    @this_is_current_user = current_user && (@user == current_user)

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @user, filter_user: current_user }
    end
  end

  # === STRIPE-RELATED STUFF === #

  # POST /users/cards?stripe_token=abc123
  # Adds a new card to the current user's stripe account
  def add_card
    respond_to do |format|
      format.json do     
        @poller_id = current_user.add_stripe_card(params[:stripe_token], true)
        render json: { poller_id: @poller_id }
      end
    end
  end

  # DELETE /users/card/1
  # Accepts page parameters: id
  # Deletes a card from the user's stripe account
  def delete_card
    respond_to do |format|
      format.json do     
        @poller_id = current_user.delete_stripe_card(params[:id], true)
        render json: { poller_id: @poller_id }
      end
    end
  end

  # GET /users/payments
  # Accepts page parameters: page, page_size
  # Gets the current user's payment history and returns it in json hash
  def payment_history
    respond_to do |format|
      format.json do     
        @page = (params[:page] || 1).to_i
        @page_size = (params[:page_size] || APP_CONFIG['page_size_normal']).to_i
        @payments = current_user.info_items.where(type: 'stripe-event')\
          .order_by("created_at desc").page(@page).per(@page_size) rescue []
        @has_more_pages = @payments.total_count > (@page * @page_size)

        render json: { page: @page, count: @payments.count, total_count: @payments.total_count,
          has_more_pages: @has_more_pages, payments: @payments }
      end
    end
  end


private

  def badge_list_admin
    unless current_user && current_user.admin?
      redirect_to '/'
    end  
  end

end