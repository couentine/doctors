class GroupsController < ApplicationController
  include EmailTools

  # === FILTERS === #

  # RESTful Actions >> :index, :show, :new, :edit, :create, :update, :destroy
  # Non-RESTful Actions >> :leave, :destroy_user, :destroy_invited_user, 
  #                        :add_users, :create_users

  prepend_before_filter :find_group, only: [:show, :edit, :update, :destroy, :cancel_subscription,
    :join, :leave, :destroy_user, :send_invitation, :destroy_invited_user, :add_users, 
    :create_users, :clear_bounce_log]
  before_filter :authenticate_user!, except: [:show]
  before_filter :group_member_or_admin, only: [:leave]
  before_filter :group_admin, only: [:update, :destroy_user, :destroy_invited_user, :add_users, 
    :create_users, :clear_bounce_log]
  before_filter :group_owner, only: [:edit, :destroy, :cancel_subscription]
  before_filter :badge_list_admin, only: [:index]

  # === CONSTANTS === #

  GROUP_TYPE_OPTIONS = [
    ['<b><i class="fa fa-globe"></i> Open Group</b><span>Anyone can join '.html_safe \
      + 'and everything is public.<br>Free forever.</span>'.html_safe, 'open'],
    ['<b><i class="fa fa-users"></i> Closed Group</b><span>You control privacy '.html_safe \
      + 'and membership.<br>Plans start at $5 per month.</span>'.html_safe, 'private']
  ]
  PRICING_GROUP_OPTIONS = [
    ['Standard Pricing', 'standard'],
    ['K12 Pricing', 'k12']
  ]
  GROUP_VISIBILITY_OPTIONS = [
    ['<i class="fa fa-globe"></i> Public'.html_safe, 'public'],
    ['<i class="fa fa-users"></i> Private'.html_safe, 'private']
  ]

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

  # GET /group-url
  # GET /group-url.json
  def show
    @badge_poller_id = params[:badge_poller]
    @join_code = params[:code]
    @bl_admin_mode = @badge_list_admin && params[:bl_admin_mode]
    @show_emails = (@current_user_is_admin || @badge_list_admin) && params[:show_emails]

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
    @expert_count_map = {} # maps from badge id to expert count
    @learner_count_map = {} # maps from badge id to learner count
    @badge_ids = []
    @badges.each do |badge|
      @badge_ids << badge.id
      @expert_count_map[badge.id], @learner_count_map[badge.id] = 0, 0
    end

    @group_visibility_options = GROUP_VISIBILITY_OPTIONS

    respond_to do |format|
      format.any(:html, :js) do # show.html.erb
        @requirements_map = {} # maps from badge id to requirements
        Tag.where(:badge.in => @badge_ids, type: 'requirement').asc(:sort_order).each do |tag|
          if @requirements_map.has_key? tag.badge_id
            @requirements_map[tag.badge_id] << tag
          else
            @requirements_map[tag.badge_id] = [tag]
          end
        end

        @log_map = {} # maps from badge id to log of current user if present
        current_user.logs.where(:badge_id.in => @badge_ids).each do |log|
          @log_map[log.badge_id] = log
        end if current_user

        Log.where(:badge.in => @badge_ids).each do |log|
          if log.validation_status == 'validated'
            @expert_count_map[log.badge_id] += 1
          else
            @learner_count_map[log.badge_id] += 1
          end
        end
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
      @badge_list_admin = current_user && current_user.admin?
      @allow_url_editing = true;
      subscription_plan = params[:plan]

      if subscription_plan
        @group.type = 'private'
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
  end

  # POST /groups
  # POST /groups.json
  def create
    @group = Group.new(params[:group])
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
      if @group.update_attributes(params[:group])
        format.html { redirect_to @group, 
                      notice: 'Group was successfully updated.' }
        format.json { head :no_content }
      else
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
        @poller_id = @group.cancel_stripe_subscription(true, true)
        render json: { poller_id: @poller_id }
      end
    end
  end

  # POST /group-url/join?code=123
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

    redirect_to @group, :notice => notice
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
            current_user.id, @group.id, badge_ids)
        else
          NewUserMailer.delay.group_member_add(found_user["email"], found_user["name"], 
            current_user.id, @group.id, badge_ids)
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
      # Query for the badges if param is included
      badge_urls = params["badges"] || []
      @badge_list = []
      @group.badges.asc(:name).each do |badge|
        @badge_list << {
          badge: badge,
          selected: badge_urls.include?(badge.url)
        }
      end
    end
  end

  # PUT /group-url/members?type=member
  # PUT /group-url/admins?type=admin
  # :emails => '"Bob Smith" <bob@example.com>, another@example.com \n yet@example.com'
  # :badges[] => ["badge-url1","badge-url2"] >> Users with be added/invited to these
  # :notify_by_email => boolean
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

      # Parse the emails using the UsersHelper function
      parsed_emails = parse_emails(params[:emails])
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
            badge_ids = []
            if @type == :admin
              users_to_add.each do |user|
                if @group.has_admin?(user)
                  @skipped_admin_emails << user.email
                  @badges.each { |badge| badge.add_learner user }
                else
                  @group.admins << user
                  @badges.each { |badge| badge.add_learner user }
                  if @notify_by_email
                    if user.email_inactive
                      # Mock a bounce so that the group admins can see that the email wasn't sent
                      @group.log_bounced_email(user.email, Time.now, true)
                    else
                      UserMailer.delay.group_admin_add(user.id, current_user.id, @group.id, 
                        badge_ids)
                    end
                  end
                  if @group.has_member?(user)
                    @group.members.delete(user)
                    @upgraded_member_emails << user.email
                  else
                    @new_admin_emails << user.email
                  end
                end
              end
            else
              users_to_add.each do |user|
                if @group.has_member?(user)
                  @skipped_member_emails << user.email
                  @badges.each { |badge| badge.add_learner user }
                elsif @group.has_admin?(user)
                  @skipped_admin_emails << user.email
                  @badges.each { |badge| badge.add_learner user }
                else
                  @group.members << user
                  @badges.each { |badge| badge.add_learner user }
                  if @notify_by_email
                    if user.email_inactive
                      # Mock a bounce so that the group admins can see that the email wasn't sent
                      @group.log_bounced_email(user.email, Time.now, true)
                    else
                      UserMailer.delay.group_member_add(user.id, current_user.id, @group.id, 
                        badge_ids)
                    end
                  end
                  @new_member_emails << user.email

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
            invited_user = {:email => email, 
              :name => name_from_email[email], :invite_date => invite_date }
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
                    current_user.id, @group.id, badge_ids)
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
                      current_user.id, @group.id, badge_ids) 
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

private

  def find_group
    # Note: Downcase is handled by group model
    @group = Group.find(params[:id] || params[:group_id]) || not_found
    @current_user_is_admin = current_user && @group.has_admin?(current_user)
    @current_user_is_member = current_user && @group.has_member?(current_user)
    @current_user_is_owner = current_user && (@group.owner_id == current_user.id)
    @badge_list_admin = current_user && current_user.admin?

    # Set user visibility variables
    @can_see_members = @group.public? \
      || (@group.member_visibility == 'public') \
      || ((@group.member_visibility == 'private') \
        && (@current_user_is_admin || @current_user_is_member || @badge_list_admin))
    @can_see_admins = @group.public? \
      || (@group.admin_visibility == 'public') \
      || ((@group.admin_visibility == 'private') \
        && (@current_user_is_admin || @current_user_is_admin || @badge_list_admin))

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

  def badge_list_admin
    unless current_user && current_user.admin?
      redirect_to '/'
    end  
  end

end
