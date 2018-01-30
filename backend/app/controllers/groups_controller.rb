class GroupsController < ApplicationController
  include EmailTools

  # === FILTERS === #

  # RESTful Actions >> :index, :show, :new, :edit, :create, :update, :destroy
  # Non-RESTful Actions >> :join, :leave, :update_group_settings, :destroy_user, 
  #                        :destroy_invited_user, :add_users, :create_users

  prepend_before_action :find_group, only: [:get, :show, :edit, :update, :destroy, :cancel_subscription, :join, :leave, 
    :update_group_settings, :destroy_user, :send_invitation, :destroy_invited_user, :users, :badges, :add_users, :create_users, 
    :clear_bounce_log, :copy_badges_form, :copy_badges_action, :review, :full_logs, :create_validations, :create_lti_key, :destroy_lti_key, 
    :update_lti_context, :destroy_lti_context]
  before_action :authenticate_user!, except: [:get, :show]
  before_action :group_member_or_admin, only: [:leave, :update_group_settings, :users, :badges, :review, :full_logs, :create_validations]
  before_action :group_admin, only: [:update, :destroy_user, :destroy_invited_user, :add_users, :create_users, :clear_bounce_log, 
    :create_lti_key, :destroy_lti_key, :update_lti_context, :destroy_lti_context]
  before_action :group_owner, only: [:edit, :destroy, :cancel_subscription]
  before_action :can_copy_badges, only: [:copy_badges_form, :copy_badges_action]
  before_action :badge_list_admin, only: [:index]

  # === CONSTANTS === #

  PERMITTED_PARAMS = [:name, :url_with_caps, :description, :location, :website, :color, :image_url, :type, :customer_code, 
    :validation_threshold, :new_owner_username, :pricing_group, :subscription_plan, 
    :user_limit_override, :admin_limit_override, :full_member_group_override, :limited_member_group_override,
    :feature_grant_file_uploads, :feature_grant_reporting, :feature_grant_bulk_tools, :feature_grant_integration, 
    :feature_grant_leaderboards_weekly, :feature_grant_leaderboards_realtime,
    :stripe_subscription_card, :revive_subscription, :member_visibility, :admin_visibility, :badge_copyability, 
    :join_code, :avatar_key, :tag_assignability, :tag_creatability, :tag_visibility, :welcome_message, :welcome_badge_tag, :joinability]

  MAX_EMAIL_TEXT_LENGTH = 1500
  MAX_INVITATION_MESSAGE_LENGTH = 500
  GROUP_TYPE_OPTIONS = [
    ['<b><i class="fa fa-check-circle free-icon"></i> Free Group</b><span> Everything is public. Free forever.</span>'.html_safe, 'free'],
    ['<b><i class="fa fa-diamond"></i> Paid Group</b><span>Incluce privacy controls and advanced features.</span>'.html_safe, 'paid']
  ]
  GROUP_COLOR_OPTIONS = [
    ['Red', 'red'],
    ['Pink', 'pink'],
    ['Purple', 'purple'],
    ['Deep Purple', 'deep-purple'],
    ['Indigo', 'indigo'],
    ['Blue', 'blue'],
    ['Light Blue', 'light-blue'],
    ['Cyan', 'cyan'],
    ['Teal', 'teal'],
    ['Green', 'green'],
    ['Light Green', 'light-green'],
    ['Lime', 'lime'],
    ['Yellow', 'yellow'],
    ['Amber', 'amber'],
    ['Orange', 'orange'],
    ['Deep Orange', 'deep-orange'],
    ['Brown', 'brown'],
    ['Grey', 'grey'],
    ['Blue Grey', 'blue-grey']
  ]
  GROUP_JOINABILITY_OPTIONS = [
    ['<i class="fa fa-globe"></i> Open to Public'.html_safe, 'open'],
    ['<i class="fa fa-lock"></i> By Invitation Only'.html_safe, 'closed']
  ]
  PRICING_GROUP_OPTIONS = [
    ['Standard Pricing', 'standard'],
    ['K12 Pricing', 'k12']
  ]
  GROUP_VISIBILITY_OPTIONS = [
    ['<i class="fa fa-globe"></i> Public'.html_safe, 'public'],
    ['<i class="fa fa-users"></i> Private'.html_safe, 'private']
  ]
  BADGE_COPYABILITY_OPTIONS = [
    ['<i class="fa fa-globe"></i> Public'.html_safe, 'public'],
    ['<i class="fa fa-users"></i> Only Members'.html_safe, 'members'],
    ['<i class="fa fa-lock"></i> Only Admins'.html_safe, 'admins']
  ]
  TAG_ASSIGNABILITY_OPTIONS = [
    ['<i class="fa fa-users"></i> All Members'.html_safe, 'members'], 
    ['<i class="fa fa-lock"></i> Only Admins'.html_safe, 'admins']
  ]
  TAG_CREATABILITY_OPTIONS = TAG_ASSIGNABILITY_OPTIONS
  TAG_VISIBILITY_OPTIONS = BADGE_COPYABILITY_OPTIONS

  # === RESTFUL ACTIONS === #

  # GET /a/groups
  # GET /a/groups.json
  # Accepts page parameters: page, page_size, sort_by, sort_order, type, plan, status
  def index
    # Grab the current page of groups
    @page = params[:page] || 1
    @page_size = params[:page_size] || APP_CONFIG['page_size_normal']
    @types = (params[:type]) ? [params[:type]] : (Group::TYPE_VALUES + ['', nil])
    @plans = (params[:plan]) ? [params[:plan]] : (ALL_SUBSCRIPTION_PLANS.keys + ['', nil])
    @stati = (params[:status]) ? [params[:status]] \
      : ['trialing', 'active', 'past_due', 'canceled', 'unpaid', 'new', '', nil]
    @sort_by = params[:sort_by] || "created_at"
    @sort_order = params[:sort_order] || "desc"
    
    @groups = Group.where(:type.in => @types, :subscription_plan.in => @plans, \
      :stripe_subscription_status.in => @stati)\
      .order_by("#{@sort_by} #{@sort_order}").page(@page).per(@page_size)

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @groups, filter_user: current_user }
    end
  end

  # GET /?page=1
  # Returns JSON
  # This returns a list of the current user's groups
  def my_index
    @page_size = APP_CONFIG['page_size_small']
    
    @page = (params[:page] || 1).to_i
    @groups = Group.array_json(current_user.groups(false).asc(:name).page(@page).per(@page_size), 
      :api_v1, current_user: current_user)
    
    if current_user.groups(false).count > (@page_size * @page)
      @next_page = @page + 1
    else
      @next_page = nil
    end

    render json: { next_page: @next_page, items: @groups }
  end

  # GET /group-url
  # Returns JSON
  # Returns group API json
  def get
    render json: @group.json(:api_v1, current_user: current_user)
  end

  # GET /group-url
  # GET /group-url.json
  def show
    @badge_poller_id = params[:badge_poller]
    @join_code = params[:code]
    @bl_admin_mode = @badge_list_admin && params[:bl_admin_mode]
    @show_emails = (@current_user_is_admin || @badge_list_admin) && params[:show_emails]
    @validation_request_count = 0

    # Get paginated versions of members
    @member_page = params[:pm] || 1
    @member_page_size = params[:psm] || APP_CONFIG['page_size_small']
    @members = @group.members.asc(:name).page(@member_page).per(@member_page_size)

    # Get paginated versions of badges
    @badge_page = params[:pb] || 1
    @badge_page_size = params[:psb] || APP_CONFIG['page_size_small']
    if @current_user_is_admin || @badge_list_admin
      @badges = @group.badges.asc(:name).page(@badge_page).per(@badge_page_size)
    elsif @current_user_is_member
      current_user_badge_ids = current_user.logs\
        .where(:badge_id.in => @group.badge_ids).pluck(:badge_id)
      @badges = @group.badges.any_of(
          {:visibility.ne => 'hidden'}, {:id.in => current_user_badge_ids}
        ).asc(:name).page(@badge_page).per(@badge_page_size)
    else
      @badges = @group.badges.where(visibility: 'public').asc(:name).page(@badge_page)\
        .per(@badge_page_size)
    end
    @has_badges = !@badges.blank?

    # Set validation_request_count by querying for all badges which this user can award which have
    # pending requests.
    if @current_user_is_admin || @badge_list_admin
      @validation_request_count = @group.badges.where(:validation_request_count.gt => 0)\
        .sum{ |badge| badge.validation_request_count }
    elsif current_user
      @validation_request_count = @group.badges.where(:validation_request_count.gt => 0, 
        :awardability => 'experts', :expert_user_ids.in => [current_user.id])\
        .sum{ |badge| badge.validation_request_count }
    else
      @validation_request_count = 0
    end
    
    # Set group tag variables
    @has_tags = !@group.tags_cache.blank?
    @top_user_tags = @group.top_user_tags(10)
    @top_badge_tags = @group.top_badge_tags(10)
    @has_top_user_tags = !@top_user_tags.blank?
    @has_top_badge_tags = !@top_badge_tags.blank?
    @badge_tag_options = [['', 'None'], [Group::WELCOME_BADGE_TAG_ALL_BADGES, 'All Badges']] \
      + @group.top_badge_tags.map do |group_tag_item| 
        [group_tag_item['name'], "##{group_tag_item['name_with_caps']}"]
      end

    # Set options vars
    @group_joinability_options = GROUP_JOINABILITY_OPTIONS
    @group_visibility_options = GROUP_VISIBILITY_OPTIONS
    @badge_copyability_options = BADGE_COPYABILITY_OPTIONS
    @tag_assignability_options = TAG_ASSIGNABILITY_OPTIONS
    @tag_creatability_options = TAG_CREATABILITY_OPTIONS
    @tag_visibility_options = TAG_VISIBILITY_OPTIONS

    # Get current values of group membership settings
    if @current_user_is_admin || @current_user_is_member
      @show_on_badges = current_user.get_group_settings_for(@group)['show_on_badges']
      @show_on_profile = current_user.get_group_settings_for(@group)['show_on_profile']
    end

    respond_to do |format|
      format.any(:html, :js) do 
        # show.html.erb
      end
      format.json { render json: @group, filter_user: current_user }
    end
  end

  # GET /groups/new?plan=abc123
  # GET /groups/new.json
  # Accepts 'plan' parameter to set pricing group (only accepts 'k12' for now)
  # Also looks for :plan key on the current user's session
  def new
    subscription_plan = session[:plan]
    if subscription_plan
      session[:plan] = nil # clear this out for next time
      redirect_to "/groups/new?plan=#{subscription_plan}"
    else
      @group = Group.new
      @group.creator = @group.owner = current_user
      @group_type_options = GROUP_TYPE_OPTIONS
      @pricing_group_options = PRICING_GROUP_OPTIONS
      @badge_list_admin = current_user && current_user.admin? && (params['suppress_bl_admin'] != 'true')
      @allow_url_editing = true;
      subscription_plan = params[:plan]

      # Create the carrierwave direct uploader
      @uploader = Group.new.direct_avatar
      @uploader.success_action_redirect = image_key_url

      if subscription_plan
        @group.type = 'paid'
        if ALL_SUBSCRIPTION_PLANS[subscription_plan] \
            && ['standard', 'k12'].include?(SUBSCRIPTION_PRICING_GROUP[subscription_plan])
          @group.pricing_group = SUBSCRIPTION_PRICING_GROUP[subscription_plan]
          @group.subscription_plan = subscription_plan
        end
      end

      respond_to do |format|
        format.html # new.html.erb
        format.json { render json: @group, filter_user: current_user }
      end
    end
  end

  # GET /group-url/edit
  # Accepts transfer=true param
  def edit
    @group_type_options = GROUP_TYPE_OPTIONS
    @pricing_group_options = PRICING_GROUP_OPTIONS
    @allow_url_editing = (@group.member_ids.count == 0) || (@group.badge_ids.count == 0);
    @transfer_mode = params[:transfer]

    # Create the carrierwave direct uploader
    @uploader = Group.new.direct_avatar
    @uploader.success_action_redirect = image_key_url
  end

  # POST /groups
  # POST /groups.json
  def create
    @group = Group.new(group_params)
    @group.creator = @group.owner = current_user
    @group_type_options = GROUP_TYPE_OPTIONS
    @pricing_group_options = PRICING_GROUP_OPTIONS
    @badge_list_admin = current_user && current_user.admin?

    respond_to do |format|
      if @group.save
        format.html { redirect_to @group, 
                      notice: 'Group was successfully created.' }
        format.json { render json: @group, status: :created, location: @group, 
          filter_user: current_user }
      else
        @allow_url_editing = true;
        
        # Create the carrierwave direct uploader
        @uploader = @group.direct_avatar
        @uploader.success_action_redirect = image_key_url

        format.html { render action: "new" }
        format.json { render json: @group.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /group-url
  # PUT /group-url.json
  # Accepts transfer=true param
  def update
    @transfer_mode = params[:transfer]

    respond_to do |format|
      if @group.update_attributes(group_params)
        format.html { redirect_to @group, 
                      notice: 'Group was successfully updated.' }
        format.json { head :no_content }
      else
        # Create the carrierwave direct uploader
        @uploader = Group.new.direct_avatar
        @uploader.success_action_redirect = image_key_url
        
        format.html { render action: "edit" }
        format.json { render json: @group.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /group-url
  # DELETE /group-url.json
  def destroy
    if @group.badges.count == 0
      @group.destroy

      respond_to do |format|
        format.html { redirect_to root_url }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html { redirect_to @group, 
          alert: 'There was a problem deleting this group. ' \
          + 'You must first individually delete each of the badges in the group.' }
        format.json { head :no_content }
      end
    end
  end

  # === NON-RESTFUL ACTIONS === #

  # POST /group-url/cancel
  # Cancels the group's subscription (asynchronous with a poller)
  def cancel_subscription
    respond_to do |format|
      format.json do     
        @poller_id = @group.cancel_stripe_subscription
        render json: { poller_id: @poller_id.to_s }
      end
    end
  end

  # POST or GET /group-url/join?code=123
  def join
    notice = ""
    join_code = params[:code]

    if @group.has_member?(current_user)
      notice = "You are already a member of this group."
    elsif @group.has_admin?(current_user)
      notice = "You are already an admin of this group."
    elsif !@group.open? && (@group.join_code == nil) 
      notice = "This is a closed group, you cannot join without being invited."
    elsif !@group.open? && (join_code != @group.join_code) 
      notice = "The join code you entered (#{join_code}) is incorrect."
    else
      @group.members << current_user
      if @group.save
        # Create / restore the user's group settings (use default values)
        current_user.initialize_group_settings_for(@group)
        current_user.timeless.save

        if join_code.blank?
          notice = "Welcome to the group!"
        else
          notice = "Your join code was accepted, welcome to the group!"
        end

        # Then update analytics
        IntercomEventWorker.perform_async({
          'event_name' => 'group-join',
          'email' => current_user.email,
          'created_at' => Time.now.to_i,
          'metadata' => {
            'group_id' => @group.id.to_s,
            'group_name' => @group.name,
            'group_url' => @group.group_url,
            'join_type' => 'joined'
          }
        })
      else
        notice = "There was a problem adding you to the group, please try again later."
      end
    end

    redirect_to @group, :notice => notice
  end

  # DELETE /group-url/leave
  def leave
    notice = "You aren't a member of this group, so you can't leave it."
    
    # First leave the group
    if @group.has_member?(current_user)
      @group.members.delete(current_user)
      notice = "You have left this group."
    elsif @group.has_admin?(current_user)
      if @group.admins.count > 1
        @group.admins.delete(current_user)
        notice = "You have left this group."
      else
        notice = "You are currently the only admin and cannot leave the group."
      end
    end

    # Then update analytics
    IntercomEventWorker.perform_async({
      'event_name' => 'group-depart',
      'email' => current_user.email,
      'created_at' => Time.now.to_i,
      'metadata' => {
        'group_id' => @group.id.to_s,
        'group_name' => @group.name,
        'group_url' => @group.group_url,
        'join_type' => 'left'
      }
    })

    # Then detach any logs
    current_user.logs.where(:badge_id.in => @group.badge_ids).each do |log_to_detach|
      log_to_detach.detached_log = true
      log_to_detach.save!
    end
    
    # Then remove them from any related tags (asynchronously)
    Group.delay(queue: 'low')\
      .remove_users_from_all_tags(@group.id, [current_user.id], current_user.id)

    redirect_to @group, :notice => notice
  end

  # PUT /group-url/settings?show_on_badges=true&show_on_profile=true
  # Updates group settings for current user
  def update_group_settings
    # Get the params (convert from string and default to true if missing)
    show_on_badges = params['show_on_badges'].to_s.downcase != 'false'
    if !show_on_badges
      show_on_profile = false
    else
      show_on_profile = params['show_on_profile'].to_s.downcase != 'false'
    end

    # Do the actual update
    current_user.update_group_settings_for(@group, show_on_badges, show_on_profile)
    if current_user.save
      redirect_to @group, notice: 'Your group membership settings have been successfully updated.'
    else
      redirect_to @group, 
        alert: 'There was a problem updating your group membership settings, please try again.'
    end
  end

  # DELETE /group-url/members/2, :id = 1, :user_id = 2, :type = member
  # DELETE /group-url/admins/2, :id = 1, :user_id = 2, :type = admin
  def destroy_user
    @user = User.find(params[:user_id])
    @notice = "That user is not a #{params[:type]}!"
    @is_error = true
    detached_log_count = 0

    if params[:type] == 'admin' && @group.has_admin?(@user)
      @group.admins.delete(@user)
      @group.members << @user
      @group.save
      @notice = "#{@user.name} has been downgraded from an admin to a member."
      @is_error = false
    elsif params[:type] == 'member' && @group.has_member?(@user)
      @group.members.delete(@user)
      @group.save

      # Then update analytics
      IntercomEventWorker.perform_async({
        'event_name' => 'group-depart',
        'email' => @user.email,
        'created_at' => Time.now.to_i,
        'metadata' => {
          'group_id' => @group.id.to_s,
          'group_name' => @group.name,
          'group_url' => @group.group_url,
          'join_type' => 'removed'
        }
      })

      # Then detach any logs
      @user.logs.where(:badge_id.in => @group.badge_ids).each do |log_to_detach|
        log_to_detach.detached_log = true
        log_to_detach.save!
        detached_log_count += 1
      end

      # Then remove them from any related tags (asynchronously)
      Group.delay(queue: 'low')\
        .remove_users_from_all_tags(@group.id, [@user.id], current_user.id)

      @notice = "#{@user.name} has been removed from the group members"
      @notice += " and dropped from #{detached_log_count} badges" if detached_log_count > 0
      @notice += "."
      @is_error = false
    end

    respond_to do |format|
      format.html { redirect_to @group, :notice => @notice }
      format.js # destroy_user.js.erb
    end
  end

  # POST /group-url/invited_members/{email}/invitation, :type = member
  # POST /group-url/invited_admins/{email}/invitation, :type = admin
  def send_invitation
    @email = params[:email].downcase
    @notice = nil
    invited_users = params[:type] == 'admin' ? 
                                    @group.invited_admins : @group.invited_members
    found_user = invited_users.detect { |u| u["email"] == @email}

    if found_user
      email_inactive = User.get_inactive_email_list.include? @email

      # Query for the badges if param is included
      if found_user["badges"].blank?
        @badges, badge_ids = [], []
      else
        @badges = @group.badges.where(:url.in => found_user["badges"])
        badge_ids = @badges.map{ |b| b.id }
      end

      if email_inactive
        found_user[:invite_date] = nil
        # Mock a bounce so that the group admins can see that the email wasn't sent
        @group.log_bounced_email(@email, Time.now, true)
      else
        if params[:type] == 'admin'
          NewUserMailer.delay.group_admin_add(found_user["email"], found_user["name"], 
            current_user.id, @group.id, badge_ids, found_user["invitation_message"])
        else
          NewUserMailer.delay.group_member_add(found_user["email"], found_user["name"], 
            current_user.id, @group.id, badge_ids, found_user["invitation_message"])
        end
        found_user[:invite_date] = Time.now
      end

      if !@group.save
        @notice = "There was a problem updating the group, please try again later."
      elsif email_inactive
        @notice = "The email address #{@email} is currently blocked and cannot receive messages. " \
          + "But the user will still be added to the group when they create a Badge List account."  
      else
        @notice = "Invitation resent"  
      end
    else
      @notice = "There is no pending group invitation for #{@email}."
    end

    respond_to do |format|
      format.html { redirect_to @group, :notice => @notice }
      format.js # send_invitation.js.erb
    end
  end

  # DELETE /group-url/invited_members/{email}, :type = member
  # DELETE /group-url/invited_admins/{email}, :type = admin
  def destroy_invited_user
    @email = params[:email].downcase
    @notice = nil
    invited_users = params[:type] == 'admin' ? 
                                    @group.invited_admins : @group.invited_members
    found_user = invited_users.detect { |u| u["email"] == @email}

    if found_user
      invited_users.delete(found_user)
      if !@group.save
        @notice = "There was a problem updating the group, please try again later."
      else
        @notice = "Group invitation for #{@email} has been revoked."  
      end
    else
      @notice = "There's no pending group invitation for #{@email}."
    end

    respond_to do |format|
      format.html { redirect_to @group, :notice => @notice }
      format.js # destroy_invited_user.js.erb
    end
  end

  # POST /group-url/clear_bounce_log
  def clear_bounce_log
    @notice = nil
    
    if @group.bounced_email_log.blank?
      @notice = "The bounced email log is already empty!"
    else
      @group.bounced_email_log = []

      if @group.save
        @notice = "The bounced email log has been cleared."  
      else
        @notice = "There was a problem updating the group, please try again later."
      end
    end

    redirect_to @group, :notice => @notice
  end

  # GET /group-url/users?without_tag=group-tag-name
  # Also accepts pagination params: page, page_size (default 200, max 200), sort_order, sort_by
  # JSON only
  # Returns json array of members with keys from User group_list_item json template
  def users
    sort_fields = ['name', 'username'] # defaults to first value
    sort_orders = ['asc', 'desc'] # defaults to first value

    without_tag_param = params['without_tag']
    
    @page = (params['page'] || 1).to_i
    @page_size = [(params['page_size'] || 200).abs, 200].min # no more than 200, default to 200
    @sort_by = (sort_fields.include? params['sort_by']) ? params['sort_by'] : sort_fields.first
    @sort_order = \
      (sort_orders.include? params['sort_order']) ? params['sort_order'] : sort_orders.first

    # Build out the users list
    @users = []
    user_criteria = @group.users(without_tag_name: without_tag_param)\
      .page(@page).per(@page_size).order_by("#{@sort_by} #{@sort_order}")
    user_criteria.each do |user|
      @users << user.json(:group_list_item)
    end
    @next_page = @page + 1 if user_criteria.count > (@page_size * @page)

    respond_to do |format|
      format.json do
        render json: { page: @page, page_size: @page_size, sort_by: @sort_by, 
          sort_order: @sort_order, users: @users, next_page: @next_page }
      end
    end
  end

  # GET /group-url/members/add?type=member
  # GET /group-url/admins/add?type=admin
  # :badges[] => ["badge-url1","badge-url2"] >> Sets which badges should be checked by default
  def add_users
    if params[:type] == 'admin'
      @type = :admin
      @form_path = create_group_admins_path(@group)
    else
      @type = :member
      @form_path = create_group_members_path(@group)
    end

    if (@type == :admin) && !@group.can_add_admins?
      redirect_to @group, notice: 'You cannot add new admins to this group.'
    elsif (@type == :member) && !@group.can_add_members?
      redirect_to @group, notice: 'You cannot add new members to this group.'
    else
      badge_urls = params["badges"] || []
      @badge_options = @group.badges_cache.values.sort_by{ |bi| bi['name'] }.each do |badge_item|
        badge_item['selected'] = badge_urls.include?(badge_item['url'])
      end
    end
  end

  # PUT /group-url/members?type=member
  # PUT /group-url/admins?type=admin
  # :emails => '"Bob Smith" <bob@example.com>, another@example.com \n yet@example.com'
  # :badges[] => ["badge-url1","badge-url2"] >> Users with be added/invited to these
  # :notify_by_email => boolean
  # :invitation_message => String
  # State variables for output: 
  #   @group, @type, @invalid_emails, @upgraded_member_emails, @new_member_emails,
  #   @new_admin_emails, @skipped_member_emails, @skipped_admin_emails
  def create_users
    flash[:error] = nil if flash[:error] # Clear error if present
    @type = params[:type] == 'admin' ? :admin : :member
    @notify_by_email = params[:notify_by_email] == "1"
    @new_admin_emails = []
    @new_member_emails = []
    @upgraded_member_emails = [] # members who were upgraded to admins
    @skipped_member_emails = [] # skipped because they were already members
    @skipped_admin_emails = [] # skipped because either...
                               # type=admin >> They are already admins
                               # type=member >> Admins cannot be down-graded
    
    # Get the invitation message and truncate it if needed
    @invitation_message = params[:invitation_message]
    if !@invitation_message.blank? && (@invitation_message.length > MAX_INVITATION_MESSAGE_LENGTH)
      @invitation_message = @invitation_message.first(MAX_INVITATION_MESSAGE_LENGTH-3) + '...'
    end

    if (@type == :admin) && !@group.can_add_admins?
      redirect_to @group, notice: 'You cannot add new admins to this group.'
    elsif (@type == :member) && !@group.can_add_members?
      redirect_to @group, notice: 'You cannot add new members to this group.'
    else
      # Query for the badges if param is included
      if params["badges"].blank?
        @badges, badge_ids = [], []
      else
        @badges = @group.badges.where(:url.in => params["badges"])
        badge_ids = @badges.map{ |b| b.id }
      end

      # Parse the emails using the EmailTools function
      raw_email_text = (params[:emails] || '').first MAX_EMAIL_TEXT_LENGTH
      parsed_emails = parse_emails(raw_email_text)
      @invalid_emails = parsed_emails[:invalid]
      valid_email_names = parsed_emails[:valid]
      valid_emails = []
      name_from_email = {} # key = email, value = name
      valid_email_names.each do |item|
        valid_emails << item[:email]
        name_from_email[item[:email]] = item[:name]
      end

      if !valid_emails.empty?
        if (@type == :admin) && !@group.can_add_admins?(valid_emails.count)
          flash[:error] = "Oops! You've only got #{@group.admin_limit - @group.admin_count} " \
            + "admin spots available with your current subscription and it looks like you're " \
            + "trying to add another #{valid_emails.count} admins. Please contact support " \
            + "if you're interested in increasing your admin limit."
          render 'add_users'
        elsif (@type == :member) && !@group.can_add_members?(valid_emails.count)
          flash[:error] = "Oops! You've only got #{@group.user_limit - @group.member_count} " \
            + "member spots available with your current subscription and it looks like you're " \
            + "trying to add another #{valid_emails.count} members. You'll need to upgrade " \
            + "your groups subscription plan to increase your user limit."
          render 'add_users'
        else
          # query for users and build list of users that don't exist yet
          match_results = match_emails_to_users(valid_emails)
          users_to_add = match_results[:matched_users]
          emails_to_invite = match_results[:unmatched_emails]

          # First update analytics
          IntercomEventWorker.perform_async({
            'event_name' => (@type == :admin) ? 'group-admins-invite' : 'group-members-invite',
            'email' => current_user.email,
            'created_at' => Time.now.to_i,
            'metadata' => {
              'group_id' => @group.id.to_s,
              'group_name' => @group.name,
              'group_url' => @group.group_url,
              'invitee_count' => valid_emails.count  
            }
          })

          # For existing users: We can add them right away
          unless users_to_add.empty?
            if @type == :admin
              users_to_add.each do |user|
                if @group.has_admin?(user)
                  @skipped_admin_emails << user.email
                  @badges.each { |badge| badge.add_learner(user, update_user_async: true) }
                else
                  @group.admins << user
                  @badges.each { |badge| badge.add_learner(user, update_user_async: true) }
                  if @notify_by_email
                    if user.email_inactive
                      # Mock a bounce so that the group admins can see that the email wasn't sent
                      @group.log_bounced_email(user.email, Time.now, true)
                    else
                      UserMailer.delay.group_admin_add(user.id, current_user.id, @group.id, 
                        badge_ids, @invitation_message)
                    end
                  end
                  if @group.has_member?(user)
                    @group.members.delete(user)
                    @upgraded_member_emails << user.email
                  else
                    @new_admin_emails << user.email

                    # Create / restore the user's group settings (use default values)
                    user.initialize_group_settings_for(@group)
                    user.timeless.save
                  end
                end
              end
            else
              users_to_add.each do |user|
                if @group.has_member?(user)
                  @skipped_member_emails << user.email
                  @badges.each { |badge| badge.add_learner(user, update_user_async: true) }
                elsif @group.has_admin?(user)
                  @skipped_admin_emails << user.email
                  @badges.each { |badge| badge.add_learner(user, update_user_async: true) }
                else
                  @group.members << user
                  @badges.each { |badge| badge.add_learner(user, update_user_async: true) }
                  if @notify_by_email
                    if user.email_inactive
                      # Mock a bounce so that the group admins can see that the email wasn't sent
                      @group.log_bounced_email(user.email, Time.now, true)
                    else
                      UserMailer.delay.group_member_add(user.id, current_user.id, @group.id, 
                        badge_ids, @invitation_message)
                    end
                  end
                  @new_member_emails << user.email

                  # Create / restore the user's group settings (use default values)
                  user.initialize_group_settings_for(@group)
                  user.timeless.save

                  # Then update analytics
                  IntercomEventWorker.perform_async({
                    'event_name' => 'group-join',
                    'email' => user.email,
                    'created_at' => Time.now.to_i,
                    'metadata' => {
                      'group_id' => @group.id.to_s,
                      'group_name' => @group.name,
                      'group_url' => @group.group_url,
                      'join_type' => 'added'
                    }
                  })
                end
              end
            end
          end

          # Check if the group variables need initialization
          @group.invited_admins = [] if @group.invited_admins.nil?
          @group.invited_members = [] if @group.invited_members.nil?
          inactive_email_list = User.get_inactive_email_list

          # For new users: We will park them in an array of hashes on the group
          if params[:notify_by_email]
            invite_date = Time.now
          else
            invite_date = nil
          end
          emails_to_invite.each do |email|
            email_inactive = inactive_email_list.include? email
            invited_user = {:email => email, name: name_from_email[email], 
              invite_date: invite_date, invitation_message: @invitation_message }
            invited_user[:badges] = @badges.map{|b| b.url} unless @badges.blank?

            if @group.has_invited_admin?(email)
              @skipped_admin_emails << email
            elsif @type == :admin
              if @group.has_invited_member?(email)
                @upgraded_member_emails << email
                found_user = @group.invited_members.detect { |u| u["email"] == email}
                @group.invited_members.delete(found_user) unless found_user.nil?
              else
                @new_admin_emails << email
              end
              @group.invited_admins << invited_user
              
              if @notify_by_email
                if email_inactive
                  # Mock a bounce so that the group admins can see that the email wasn't sent
                  @group.log_bounced_email(email, Time.now, true)
                else
                  NewUserMailer.delay.group_admin_add(email, name_from_email[email],
                    current_user.id, @group.id, badge_ids, @invitation_message)
                end
              end
            else
              if @group.has_invited_member?(email)
                @skipped_member_emails << email
              else
                @group.invited_members << invited_user
                @new_member_emails << email
                
                if @notify_by_email
                  if email_inactive
                    # Mock a bounce so that the group admins can see that the email wasn't sent
                    @group.log_bounced_email(email, Time.now, true)
                  else
                    NewUserMailer.delay.group_member_add(email, name_from_email[email],
                      current_user.id, @group.id, badge_ids, @invitation_message)
                  end
                end
              end
            end
          end
          
          if !@group.save
            flash[:error] = "There was a problem updating the group, please try again later."
            render 'add_users'
          end
        end # over limit tests
      end # valid emails empty
    end # can add admins test
  end

  # GET /group-url/badges?without_tag=group-tag-name
  # Also accepts pagination params: page, page_size (default 200, max 200), sort_order, sort_by
  # JSON only
  # Returns json array of badges with keys from Badge group_list_item json template
  def badges
    sort_fields = ['name', 'url'] # defaults to first value
    sort_orders = ['asc', 'desc'] # defaults to first value

    without_tag_param = params['without_tag']
    
    @page = (params['page'] || 1).to_i
    @page_size = [(params['page_size'] || 200).abs, 200].min # no more than 200, default to 200
    @sort_by = (sort_fields.include? params['sort_by']) ? params['sort_by'] : sort_fields.first
    @sort_order = \
      (sort_orders.include? params['sort_order']) ? params['sort_order'] : sort_orders.first

    # Build out the badges list
    @badges_hash = []
    badge_criteria = @group.badges_query(without_tag_name: without_tag_param).page(@page)\
      .per(@page_size).order_by("#{@sort_by} #{@sort_order}")
    @badges_hash = Badge.array_json(badge_criteria, :group_list_item)
    @next_page = @page + 1 if badge_criteria.count > (@page_size * @page)

    respond_to do |format|
      format.json do
        render json: { page: @page, page_size: @page_size, badges: @badges_hash, 
          next_page: @next_page }
      end
    end
  end

  # GET /group-url/copy_badges
  # Presents UI for selecting a list of badges and a destination group
  def copy_badges_form
    @to_group = Group.find(params[:to_group]) rescue nil
    @to_group_options = current_user.admin_group_options except: [@group.id]

    # Now filter down the badge options based on the current user
    if @current_user_is_admin || @badge_list_admin
      @badge_options = @group.badges_cache.values
    elsif @current_user_is_member
      @badge_options = []
      @group.badges_cache.each do |badge_id, badge_item|
        if (badge_item['visibility'] == 'public') || (badge_item['visibility'] == 'private') \
            || current_user.learner_or_expert_of?(badge_id)
          @badge_options << badge_item
        end
      end
    else # they have to be logged in to get here so they are at least a user
      @badge_options = @group.badges_cache.values.select do |badge_item| 
        badge_item['visibility'] == 'public'
      end
    end
    
    @badge_options.sort_by!{ |bi| bi['name'] } unless @badge_options.blank?
  end

  # POST /group-url/copy_badges?to_group=url&badges[]=list_of_urls
  # Starts the copying process and redirects to a progress tracking poller
  # NOTE: Leave out the badges parameter to copy all of the badges
  def copy_badges_action
    @to_group = Group.find(params[:to_group]) rescue nil

    if @to_group
      if @to_group.id == @group.id
        redirect_to :copy_badges_form, alert: 'You can\'t copy badges to the same group!'
      else
        if @badge_list_admin || current_user.admin_of?(@to_group)
          # Process the badge urls
          if params[:badges].blank?
            @badge_urls = nil
          else
            @badge_urls = []
            params[:badges].each { |url| @badge_urls << url.downcase unless url.blank? }
          end

          # Then update analytics
          IntercomEventWorker.perform_async({
            'event_name' => 'copy-badges',
            'email' => current_user.email,
            'created_at' => Time.now.to_i,
            'metadata' => {
              'from_group_id' => @group.id.to_s,
              'from_group_name' => @group.name,
              'from_group_url' => @group.group_url,
              'to_group_id' => @to_group.id.to_s,
              'to_group_name' => @to_group.name,
              'to_group_url' => @to_group.group_url,
              'badge_count' => @badge_urls.blank? ? -1 : @badge_urls.count
            }
          })

          # Initiate the copy and redirect to the poller
          poller_id = @group.copy_badges_to_group(current_user.id, @badge_urls, @to_group.id, true)
          redirect_to poller_path(poller_id)
        else
          redirect_to :copy_badges_form, alert: 'You must be an admin of the destination group.'
        end
      end
    else
      redirect_to :copy_badges_form, alert: 'You must specify a valid destination group.'
    end
  end

  # === REVIEWS === #

  # GET /group-url/review?badge=badge-url&sort_by=date_requested&sort_order=asc
  # GET /group-url/review?user=username
  # GET /group-url/review?user_tag=Group-Tag-Name
  # GET /group-url/review?badge_tag=Group-Tag-Name
  # Presents UI for seeing all pending validation requests / existing experts for all badges
  # and allows bulk validation. If badge isn't set it will display a badge selection UI.
  # This method basically just queries for the badges, the actual logs come from full_logs.
  # PARAMETER NOTE: The sort params don't do anything other than get passed to page variables so
  #                 they can be made available to the layout.
  def review
    # First intialize the core parameters and variables
    badge_param = params['badge'].to_s.downcase
    user_param = params['user'].to_s.downcase
    @user_tag = (params['user_tag']) ? params['user_tag'].downcase : 'NONE'
    @badge_tag = (params['badge_tag']) ? params['badge_tag'].downcase : 'NONE'
    @badges, @users = [], []
    @badge_url, @badge_id = nil, nil
    @user_username, @user_id = nil, nil
    @list_inject_items = { badge: {} } # used by bl-list component to inject badges into full logs
    valid_badge_map = {} # badge_url => badge_id
    valid_user_map = {} # username => user_id
    current_badge_json = {}

    # Determine the mode
    if !badge_param.blank?
      @query_mode = 'badge'
      @item_display_mode = 'user'
      @back_url = group_badge_url(@group, badge_param)
    elsif !user_param.blank?
      @query_mode = 'user'
      @item_display_mode = 'badge'
      @back_url = group_url(@group)
    elsif @user_tag != 'NONE'
      @query_mode = 'user'
      @back_url = group_tag_url(@group, @user_tag)
    elsif @badge_tag != 'NONE'
      @query_mode = 'badge'
      @back_url = group_tag_url(@group, @badge_tag)
    else # no params, default = go back to group
      @back_url = group_url(@group)
    end

    # No  need to hit the DB again unless there are badges
    if @group.badge_count > 0
      # First we need to build the badge criteria
      if @current_user_is_admin || @badge_list_admin
        # Admins can access everything
        badge_criteria = @group.badges.where(:validation_request_count.gt => 0)
      else
        # Non-admins can only access badges which they can award
        badge_criteria = @group.badges.where(:validation_request_count.gt => 0, 
          :awardability => 'experts', :expert_user_ids.in => [current_user.id])
      end

      # Now do the badge query
      badge_criteria.asc(:name).each do |badge| 
        current_badge_json = badge.json(:list_item)
        @badges << current_badge_json
        @list_inject_items[:badge][badge.id.to_s] = current_badge_json
        valid_badge_map[badge.url] = badge.id
      end
      
      # Now do the user query
      User.where(:id.in => (@group.member_ids + @group.admin_ids).uniq, :id.ne => current_user.id,
          :"group_validation_request_counts.#{@group.id.to_s}".gt => 0).asc(:name).each do |user|
        @users << user.json(:group_list_item)
        valid_user_map[user.username] = user.id
      end
      
      # Set variables only if the param is accurate 
      # Leave blank if invalid (user will be presented with selection screen on load)
      # NOTE: The way this is currently written only verifies access not if param matches query
      if (@query_mode == 'badge') && valid_badge_map.has_key?(badge_param)
        @badge_url = badge_param
        @badge_id = valid_badge_map[badge_param]
      elsif (@query_mode == 'user') && valid_user_map.has_key?(user_param)
        @user_username = user_param
        @user_id = valid_user_map[user_param]
      end

      # Now query for tags which have users/badges and pending validation requests
      @user_tags = GroupTag.array_json(
        @group.user_tags.where(:user_validation_request_count.gt => 0), :list_with_children)
      @badge_tags = GroupTag.array_json(
        @group.badge_tags.where(:badge_validation_request_count.gt => 0), :list_with_children)
    end

    # Build the default query options parameter for the bl-list component
    # That involves querying the extra parameters
    sort_fields = ['date_requested', 'user_name'] # defaults to first value
    sort_orders = ['desc', 'asc'] # defaults to first value
    @sort_by = (sort_fields.include? params['sort_by']) ? params['sort_by'] : sort_fields.first
    @sort_order = \
      (sort_orders.include? params['sort_order']) ? params['sort_order'] : sort_orders.first
    @sort_options = { sort_by: @sort_by, sort_order: @sort_order }.to_json

    if (@query_mode == 'user')
      @query_options = { \
        user: @user_username, sort_by: @sort_by, sort_order: @sort_order }.to_json
    else 
      @query_options = { \
        badge: @badge_url, sort_by: @sort_by, sort_order: @sort_order }.to_json
    end

    # Now we can respond
    render layout: 'app'
  end

  # GET /group-url/full_logs?badge=badge-url&page=1&page_size=50&sort_by=date_requested
  #                        &sort_order=asc
  # GET /group-url/full_logs?user=username
  # This is a JSON only method for querying for the full logs that are at requested status for the
  # specified badge OR user. It will filter the info based on current user's permissions.
  # Specify only ONE of the following parameters: badge, user
  def full_logs
    sort_fields = ['date_requested', 'user_name'] # defaults to first value
    sort_orders = ['desc', 'asc'] # defaults to first value

    badge_param = params['badge'].to_s.downcase
    user_param = params['user'].to_s.downcase
    
    @page = params['p'] || 1
    @page_size = [(params['ps'] || 50).abs, 50].min # no more than 50, default to 50
    @sort_by = (sort_fields.include? params['sort_by']) ? params['sort_by'] : sort_fields.first
    @sort_order = \
      (sort_orders.include? params['sort_order']) ? params['sort_order'] : sort_orders.first

    # Determine the type of log query we'll be doing
    if badge_param.blank? && !user_param.blank?
      @query_mode = 'user'
    else
      @query_mode = 'badge'
    end
    
    @next_page = nil
    @full_logs_hash = []
    badge_ids, user_ids = [], []
    badge_map = {} # badge id => badge

    # No need to hit the DB again unless there are badges
    if @group.badge_count > 0
      # First we need to build the base badge criteria (aka what the user can access)
      if @current_user_is_admin || @badge_list_admin
        # Admins can access everything
        badge_criteria = @group.badges
      else
        # Non-admins can only access badges which they can award
        badge_criteria = @group.badges.where(:awardability => 'experts', 
          :expert_user_ids.in => [current_user.id])
      end

      # Next we potentially pare down the badges based on the passed badge_param (if present)
      if @query_mode == 'badge'
        badge_criteria = badge_criteria.where(url: badge_param)
      end
      
      # Now we execute the badge query in order to confirm that the user has access
      # We'll only continue if there is something to query
      badge_criteria.each do |badge|
        badge_ids << badge.id
        badge_map[badge.id.to_s] = badge
      end
      if !badge_ids.blank?
        # Now we build the log criteria, the base criteria is the same no matter what
        log_criteria = Log.where(:badge_id.in => badge_ids, validation_status: 'requested', 
          detached_log: false, :user_id.ne => current_user.id, \
          :"validations_cache.#{current_user.id.to_s}".exists => false)\
          .page(@page).per(@page_size).order_by("#{@sort_by} #{@sort_order}")
        
        if @query_mode == 'user' # then we need to narrow down the criteria to one user
          log_criteria = log_criteria.where(user_username: user_param)
        end
        
        # Finally we query the logs
        @full_logs_hash = Log.full_logs_as_json(log_criteria)
        @next_page = @page + 1 if log_criteria.count > (@page_size * @page)

        # Inject the parent path into the output (Note: This is formatted according to the new polymer standard, not a traditional url path)
        @full_logs_hash.each do |full_log_item|
          if badge_map[full_log_item[:badge_id]].present?
            full_log_item[:parent_path] =  badge_map[full_log_item[:badge_id]].record_path
          else
            full_log_item[:parent_path] = nil
          end
        end
      end
    end

    # Now we can respond
    respond_to do |format|
      format.json do
        render json: { page: @page, page_size: @page_size, sort_by: @sort_by, 
          sort_order: @sort_order, full_logs: @full_logs_hash, next_page: @next_page }
      end
    end
  end

  # POST /group-url/validations?log_ids[]=abc123&summary=text&body=text&logs_validated=true
  # Initializes a bulk validation call and returns (JSON only) a poller id.
  # If there's a problem, :poller_id will be blank and :error_message will be set.
  def create_validations
    @log_ids = params['log_ids']
    @summary = params['summary']
    @body = params['body']
    @logs_validated = (params['logs_validated'] == 'true') || (params['logs_validated'] == true)
    @error_message = nil
    @poller_id = nil

    if @log_ids.blank?
      @error_message = "Log ids parameter is missing."
    elsif @summary.blank?
      @error_message = "Summary parameter is missing."
    else
      @poller_id = Log.add_validations(@log_ids, current_user.id, @summary, @body, 
        @logs_validated, true, true)
    end

    # Now we can respond
    respond_to do |format|
      format.json do
        render json: { poller_id: @poller_id.to_s, error_message: @error_message }
      end
    end
  end

  # POST /group-url/lti_keys.json?name=Display+Name+of+Key
  # Returns json hash with following keys:
  # - success: boolean
  # - lti_key: If successful returns hash w/ following keys: name, consumer_key, secret_key
  def create_lti_key
    respond_to do |format|
      format.json do
        @name = params[:name]
        @name = 'Unnamed Key' if @name.blank?
        @lti_key = @group.add_lti_key_pair(current_user, @name)

        if @group.save
          render json: { success: true, lti_key: @lti_key }
        else
          render json: { success: false, lti_key: nil }
        end
      end
    end
  end

  # DELETE /group-url/lti_keys/abc123.json
  # Deletes the specified consumer key (the abc123 part above)
  # Returns json hash with following keys:
  # - success: boolean
  # - lti_key: If successful returns hash w/ following keys: name, consumer_key, secret_key
  def destroy_lti_key
    respond_to do |format|
      format.json do
        @lti_key = @group.remove_lti_key_pair(params['consumer_key'])

        if @lti_key.present? && @group.save
          render json: { success: true, lti_key: @lti_key }
        else
          render json: { success: false, lti_key: nil }
        end
      end
    end
  end

  # PUT /group-url/lti_contexts/abc123.json?navigate_to=badge&navigate_to=xyz456
  # Updates the specified context id (the abc123 part above).
  # Returns json hash with following keys:
  # - success: boolean
  # - context: If successful returns hash w/ following keys: 
  #            context_id, name, navigate_to, navigate_to_id
  def update_lti_context
    respond_to do |format|
      format.json do
        # Get the params
        navigate_to_values = ['group', 'badge', 'group_tag'] # first is default
        @navigate_to = params['navigate_to']
        @navigate_to = navigate_to_values.first if !navigate_to_values.include? @navigate_to
        @navigate_to_id = params['navigate_to_id']
        @context_id = params['context_id']

        # Do the update and save
        @context = @group.update_lti_context_details(@context_id, @navigate_to, @navigate_to_id)
        if @context.present? && @group.save
          render json: { success: true, context: @context }
        else
          render json: { success: false, context: nil }
        end
      end
    end
  end

  # DELETE /group-url/lti_contexts/abc123.json
  # Deletes the specified context id (the abc123 part above)
  # Returns json hash with following keys:
  # - success: boolean
  # - context: If successful returns hash w/ following keys: name, context_id
  def destroy_lti_context
    respond_to do |format|
      format.json do
        @context = @group.remove_lti_context(params['context_id'])

        if @context.present? && @group.save
          render json: { success: true, context: @context }
        else
          render json: { success: false, context: nil }
        end
      end
    end
  end

private

  def find_group
    # Note: Downcase is handled by group model
    @group = Group.find(params[:id] || params[:group_id]) || not_found
    @current_user_is_admin = current_user && @group.has_admin?(current_user)
    @current_user_is_member = current_user && @group.has_member?(current_user)
    @current_user_is_owner = current_user && (@group.owner_id == current_user.id)
    @badge_list_admin = current_user && current_user.admin? \
      && (params['suppress_bl_admin'] != 'true')

    # Set user visibility variables
    @can_see_members = (@group.member_visibility == 'public') \
      || ((@group.member_visibility == 'private') \
        && (@current_user_is_admin || @current_user_is_member || @badge_list_admin))
    @can_see_admins = (@group.admin_visibility == 'public') \
      || ((@group.admin_visibility == 'private') \
        && (@current_user_is_admin || @current_user_is_admin || @badge_list_admin))

    # Set badge copyability variable
    @can_copy_badges = @badge_list_admin || @current_user_is_admin \
      || ((@group.badge_copyability == 'public') && current_user)   \
      || ((@group.badge_copyability == 'members') && @current_user_is_member)

    # Set group tag variables
    @can_assign_group_tags = @current_user_is_admin || @badge_list_admin \
      || (@current_user_is_member && (@group.tag_assignability == 'members'))
    @can_create_group_tags = @current_user_is_admin || @badge_list_admin \
      || (@current_user_is_member && (@group.tag_creatability == 'members'))
    @can_view_group_tags = (@group.tag_visibility == 'public') \
      || @current_user_is_admin || @badge_list_admin \
      || (@current_user_is_member && (@group.tag_visibility == 'members'))
    # This one is hard-coded for now...
    @can_edit_group_tags = @current_user_is_admin || @badge_list_admin
      
    # Set current group (for analytics) only if user is logged in and an admin
    @current_user_group = @group if @current_user_is_admin
  end

  def group_admin
    unless @current_user_is_admin || @badge_list_admin
      flash[:error] = "You must be an admin of #{@group.name} to do that!"
      redirect_to @group
    end 
  end

  def group_owner
    unless @current_user_is_owner || @badge_list_admin
      flash[:error] = "Only the group owner can access this functionality."
      redirect_to @group
    end 
  end

  def group_member_or_admin
    unless @current_user_is_member || @current_user_is_admin || @badge_list_admin
      flash[:error] = "You must be a member or admin of #{@group.name} to do that!"
      redirect_to @group
    end 
  end

  def can_copy_badges
    if !current_user
      flash[:error] = "You must sign in to Badge List before you can copy badges."
      redirect_to @group
    elsif !@can_copy_badges
      flash[:error] = "You do not have permission to copy badges from this group."
      redirect_to @group
    end
  end

  def badge_list_admin
    unless current_user && current_user.admin?
      redirect_to '/'
    end  
  end

  def group_params
    params.require(:group).permit(PERMITTED_PARAMS)
  end

end
