class UsersController < ApplicationController
  
  before_action :authenticate_user!, only: [:index, :add_card, :delete_card, :payment_history,
    :confirm_account, :unblock_email, :update_image, :add_password]
  before_action :badge_list_admin, only: [:index, :confirm_account, :unblock_email]

  # === CONSTANTS === #

  PERMITTED_PARAMS = [:email, :name, :username_with_caps, :password, :password_confirmation, 
    :remember_me, :avatar_key, :job_title, :organization_name, :website, :bio]

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
    @this_is_current_user = current_user && (@user == current_user)
    @group_badge_log_list = @user.group_badge_log_list(!@this_is_current_user && !@badge_list_admin)
    @current_user_can_see_profile = @user.profile_visible_to(current_user)
    @current_user_can_see_domain = @user.domain_visible_to(current_user)

    if @current_user_can_see_domain
      # Then set the properties of the private domain label
      if @user.domain_membership == 'private'
        @domain_tooltip = 'This profile can only be seen by users on the following domains: ' \
          + @user.visible_to_domain_urls.to_a.join(', ') 
        @domain_label_icon = 'fa-eye-slash'
        @domain_label_text = 'Private Domain'
      elsif @user.domain_membership == 'private-excluded'
        @domain_tooltip = 'This user is part of a private domain but their profile has been ' \
          + 'excluded from domain privacy.'
        @domain_label_icon = 'fa-eye'
        @domain_label_text = 'Private Domain'
      elsif @user.domain_membership == 'public'
        @domain_tooltip = 'This user is part of a registered domain that is visible to the public.'
        @domain_label_icon = 'fa-building'
        @domain_label_text = 'Registered Domain'
      end
    end

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
        render json: { poller_id: @poller_id.to_s }
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
        render json: { poller_id: @poller_id.to_s }
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

  # POST /u/username/confirm_account
  def confirm_account
    respond_to do |format|
      format.js do
        begin
          @user = User.find(params[:id]) || not_found

          if @user.confirmed?
            @notice = "Account already confirmed!"
            @success = true
          else
            @user.skip_confirmation!
            @user.save!
            @success = true
            @notice = "Account confirmed."
          end
        rescue Exception => e
          @success = false
          @notice = "Error: #{e}"
        end
      end
    end
  end

  # POST /u/username/unblock_email
  def unblock_email
    respond_to do |format|
      format.js do
        begin
          @user = User.find(params[:id]) || not_found
          
          if @user.email_inactive
            User.unblock_email(@user.email, true)
            @success = true
            @notice = "Email unblocked."
          else
            @notice = "Email isn't blocked!"
            @success = true
          end
        rescue Exception => e
          @success = false
          @notice = "Error: #{e}"
        end
      end
    end
  end

  # POST /u/username/update_image?avatar_key=abc/123.png
  def update_image
    @user = User.find(params[:id]) || not_found

    respond_to do |format|
      format.js do
        if @user == current_user
          @user.avatar_key = params[:avatar_key]
          if @user.save
            @success = true
            @notice = "Image updated successfully."
          else
            @success = false
            @notice = "There was a problem updating the image."
          end
        else
          @success = false
          @notice = "You can only update your own image."
        end
      end
    end
  end

  # POST /u/username/add_password?password=SuperSecret123
  def add_password
    @user = User.find(params[:id]) || not_found

    respond_to do |format|
      format.html do
        if @user == current_user
          if @user.user_defined_password
            @success = false
            @notice = "The add password feature only works if you don't already have one. " \
              + "Use the change password feature instead."
          else
            @user.password = params[:user][:password]
            @user.password_confirmation = params[:user][:password]
            @user.user_defined_password = true

            if @user.valid? && @user.save
              sign_in(@user, bypass: true) # we have to sign in again
              @success = true
              @notice = "You have successfully added a password to your account. Don't forget it!"
            else
              @success = false
              @notice = "There was a problem adding a password to your account."
              @notice += " Password #{@user.errors.first.last}." unless @user.errors.blank?
            end
          end
        else
          @success = false
          @notice = "You can only add a password to your own account!"
        end

        if @success
          redirect_to edit_user_registration_path, notice: @notice
        else
          redirect_to edit_user_registration_path, flash: { error: @notice }
        end
      end
    end
  end

private

  def badge_list_admin
    unless current_user && current_user.admin?
      redirect_to '/'
    end  
  end

  # This method isn't being used yet, directly since the registration controll handles signup
  def user_params
    params.require(:user).permit(PERMITTED_PARAMS)
  end

end