class UsersController < ApplicationController
  
  before_action :authenticate_user!, only: [:index, :add_card, :delete_card, :payment_history,
    :confirm_account, :unblock_email, :update_image, :add_password]
  before_action :badge_list_admin, only: [:index, :confirm_account, :unblock_email, :edit, :update,
    :new, :create, :new_password]

  # === CONSTANTS === #

  PERMITTED_PARAMS = [:email, :name, :username_with_caps, :password, :password_confirmation, 
    :remember_me, :avatar_key, :job_title, :organization_name, :website, :bio]

  # GET /u/username
  # GET /u/username.json
  def show
    respond_to do |format|
      
      format.html do
        # Attempt to load the user record, then look for an invited user info item if the user isn't found
        @user = User.find(params[:id])
        
        if @user.present?
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

          render :show
        else
          @info_item = InfoItem.where(type: UpdateInvitedUserService::INFO_ITEM_TYPE, key: params[:id]).first

          if @info_item.present? && 
            # Note: This code is a bit sloppy for now because it is temporary and will be unneccessary after the platform refactor.
            
            @name = @info_item.data['name']
            @email = @info_item.data['email']
            @user_key = params[:id]
            @avatar_image_url = "https://secure.gravatar.com/avatar/#{@user_key}?s=500&d=mm"
            
            # Get the domain and set the domain booleans
            domain_url = @email.split('@').last.downcase
            @domain = Domain.where(url: domain_url).first
            @current_user_can_see_domain = @domain.blank? || !@domain.is_private || (
              current_user && (current_user.admin? || @domain.visible_to_domain_ids.include?(current_user.domain_id))
            )
            @current_user_can_see_profile = @current_user_can_see_domain

            # Query the groups and badges and build a map of them by id
            @groups = Group.where(:id.in => @info_item.data['groups'].keys).asc(:name)
            group_map = @groups.map{ |group| [group.id.to_s, group] }.to_h
            
            @group_badge_list = []
            badge_urls = []

            # Build the draft version of the group badge list, but we haven't queried the badges yet so we'll just store the badge keys
            # while also collecting the badge urls in a list so we can get them all in a single query
            @info_item.data['groups'].each do |group_id, invited_user_item|
              if invited_user_item['validations'].present?
                current_badge_urls = invited_user_item['validations'].map{ |validation_item| validation_item['badge'] }.uniq
                badge_urls += current_badge_urls
                
                @group_badge_list << {
                  group: group_map[group_id],
                  badge_keys: current_badge_urls.map{ |badge_url| "#{group_id}.#{badge_url}" },
                }
              end
            end

            # Query the badges and build a map of them based on a key which contains the group id and the badge url
            badge_urls = badge_urls.uniq
            badge_map = Badge.where(:group_id.in => @info_item.data['groups'].keys, :url.in => badge_urls).map do |badge|
              ["#{badge.group_id}.#{badge.url}", badge]
            end.to_h
            
            # Loop back through the group badge list and build out the badges key by using the badge map
            @group_badge_list.each do |group_item|
              group_item[:badges] = group_item[:badge_keys].map{ |badge_key| badge_map[badge_key] }
            end

            render :show_invited 
          else
            not_found
          end
        end
      end

      format.json do
        @user = User.find(params[:id]) || not_found 
        render json: @user, filter_user: current_user
      end

    end
  end

  # === SELF-ONLY STUFF === #

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

  # === ADMIN-ONLY STUFF === #

  # GET /a/users?search=email+or+name+text
  # GET /a/users.json
  # Accepts page parameters: page, page_size, sort_by, sort_order, search
  def index
    # Grab the current page of users
    @page = params[:page] || 1
    @page_size = params[:page_size] || APP_CONFIG['page_size_normal']
    @sort_by = params[:sort_by] || "created_at"
    @sort_order = params[:sort_order] || "desc"
    @search = params['search']

    # First build the base criteria
    if @search.present?
      user_criteria = User.any_of(
        { email: /#{Regexp.quote(@search)}/i },
        { name: /#{Regexp.quote(@search)}/i },
        { username: /#{Regexp.quote(@search)}/i }
      )
    else
      user_criteria = User.all
    end

    # Now add the sort and assign the users variable
    @users = user_criteria.order_by("#{@sort_by} #{@sort_order}").page(@page).per(@page_size)

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @users, filter_user: current_user }
    end
  end

  # GET /a/users/username
  def new
    @user = User.new
  end

  # PUT /a/users/username
  def create
    @user = UserChangeDecorator.new(User.new(user_params))

    if @user.save
      flash[:notice] = 'User was successfully created.'
      redirect_to edit_user_path(@user)
    else
      flash[:error] = 'Problem creating user.'
      render 'new'
    end
  end

  # GET /a/users/username
  def edit
    @user = User.find(params[:id]) rescue not_found
    if @user.admin
      flash[:error] = 'Admin users cannot be modified using this tool.'
      redirect_to users_path
    end
  end

  # PUT /a/users/username
  def update
    @user = User.find(params[:id]) rescue not_found

    if @user.admin
      flash[:error] = 'Admin users cannot be modified using this tool.'
      redirect_to users_path
    elsif @user.update_attributes(user_params)
      flash[:notice] = 'User was successfully updated.'
      redirect_to edit_user_path(@user)
    else
      flash[:error] = 'Problem updating user.'
      render 'edit'
    end
  end

  # POST /u/username/new_password?password=abc123
  def new_password
    begin
      @user = User.find(params[:id]) || not_found
      raise StandardError.new('You cannot set the password of a Badge List admin.') if @user.admin 
      @password = params[:password]

      @user.password = @password
      @user.save!
      @success = true
      @notice = "User's password changed to '#{@password}'."
    rescue => e
      @success = false
      @notice = "Error: #{e}"
    end

    if @success
      flash[:notice] = @notice
    else
      flash[:error] = @notice
    end

    redirect_to edit_user_path(@user)
  end

  # POST /u/username/confirm_account
  def confirm_account
    begin
      @user = User.find(params[:id]) || not_found

      if @user.confirmed? && !@user.pending_reconfirmation?
        @notice = "Account already confirmed!"
        @success = true
      else
        @user.confirm
        @user.save!
        @success = true
        @notice = "Account confirmed."
      end
    rescue => e
      @success = false
      @notice = "Error: #{e}"
    end

    respond_to do |format|
      format.html do
        if @success
          flash[:notice] = @notice
        else
          flash[:error] = @notice
        end

        redirect_to edit_user_path(@user)
      end
      format.js
    end
  end

  # POST /u/username/unblock_email
  def unblock_email
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
    rescue => e
      @success = false
      @notice = "Error: #{e}"
    end

    respond_to do |format|
      format.html do
        if @success
          flash[:notice] = @notice
        else
          flash[:error] = @notice
        end

        redirect_to edit_user_path(@user)
      end
      format.js
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