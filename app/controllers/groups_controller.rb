class GroupsController < ApplicationController
  include EmailTools

  # === FILTERS === #

  # RESTful Actions >> :index, :show, :new, :edit, :create, :update, :destroy
  # Non-RESTful Actions >> :leave, :destroy_user, :destroy_invited_user, 
  #                        :add_users, :create_users

  prepend_before_filter :find_group, only: [:show, :edit, :update, :destroy, :join, :leave,
    :destroy_user, :send_invitation, :destroy_invited_user, :add_users, :create_users]
  before_filter :authenticate_user!, except: [:show]
  before_filter :group_member_or_admin, only: [:leave]
  before_filter :group_admin, only: [:destroy_user, :destroy_invited_user, :add_users, 
    :create_users]
  before_filter :group_owner, only: [:edit, :update, :destroy]
  before_filter :badge_list_admin, only: [:index]


  # === CONSTANTS === #

  GROUP_TYPE_OPTIONS = [
    ['<b>Public</b> <span>Anyone can join.<br>'.html_safe \
      + 'Free for unlimited users.</span>'.html_safe, 'open'],
    ['<b>Private</b> <span>You choose who can join the group.<br>'.html_safe \
      + 'Free 14 day trial.</span>'.html_safe, 'private']
  ]

  # === RESTFUL ACTIONS === #

  # GET /a/groups
  # GET /a/groups.json
  # Accepts page parameters: page, page_size, sort_by, sort_order, exclude_flags[]
  def index
    # Grab the current page of groups
    @page = params[:page] || 1
    @page_size = params[:page_size] || APP_CONFIG['page_size_normal']
    @exclude_flags = params[:exclude_flags] || %w(sample_data internal-data)
    @sort_by = params[:sort_by] || "active_user_count"
    @sort_order = params[:sort_order] || "desc"
    @groups = Group.where(:flags.nin => @exclude_flags).order_by("#{@sort_by} #{@sort_order}")\
      .page(@page).per(@page_size)

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @groups, filter_user: current_user }
    end
  end

  # GET /group-url
  # GET /group-url.json
  def show
    # Get paginated versions of members
    @member_page = params[:pm] || 1
    @member_page_size = params[:psm] || APP_CONFIG['page_size_small']
    @members = @group.members.asc(:name).page(@member_page).per(@member_page_size)

    # Get paginated versions of badges
    @badge_page = params[:pb] || 1
    @badge_page_size = params[:psb] || APP_CONFIG['page_size_small']
    @badges = @group.badges.asc(:url).page(@badge_page).per(@badge_page_size)
    @expert_count_map = {} # maps from badge id to expert count
    @learner_count_map = {} # maps from badge id to learner count
    @badge_ids = []
    @badges.each do |badge|
      @badge_ids << badge.id
      @expert_count_map[badge.id], @learner_count_map[badge.id] = 0, 0
    end

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

  # GET /groups/new
  # GET /groups/new.json
  def new
    @group = Group.new
    @group.creator = @group.owner = current_user
    @group_type_options = GROUP_TYPE_OPTIONS

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @group, filter_user: current_user }
    end
  end

  # GET /group-url/edit
  def edit
    @group_type_options = GROUP_TYPE_OPTIONS
  end

  # POST /groups
  # POST /groups.json
  def create
    @group = Group.new(params[:group])
    @group.creator = @group.owner = current_user
    @group_type_options = GROUP_TYPE_OPTIONS

    respond_to do |format|
      if @group.save
        format.html { redirect_to @group, 
                      notice: 'Learning Group was successfully created.' }
        format.json { render json: @group, status: :created, location: @group, filter_user: current_user }
      else
        format.html { render action: "new" }
        format.json { render json: @group.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /group-url
  # PUT /group-url.json
  def update

    respond_to do |format|
      if @group.update_attributes(params[:group])
        format.html { redirect_to @group, 
                      notice: 'Learning Group was successfully updated.' }
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
          alert: 'There was a problem deleting this learning group. ' \
          + 'You must first individually delete each of the badges in the group.' }
        format.json { head :no_content }
      end
    end
  end

  # === NON-RESTFUL ACTIONS === #

  # POST /group-url/join
  def join
    notice = ""

    if @group.has_member?(current_user)
      notice = "You are already a member of this group."
    elsif @group.has_admin?(current_user)
      notice = "You are already an admin of this group."
    elsif !@group.open?
      notice = "This is a closed group, you cannot join without being invited."
    else
      @group.members << current_user
      if @group.save
        notice = "Welcome to the group!"
      else
        notice = "There was a problem adding you to the group, please try again later."
      end
    end

    redirect_to @group, :notice => notice
  end

  # DELETE /group-url/leave
  def leave
    notice = "You aren't a member of this Learning Group, so you can't leave it."
    
    # First leave the group
    if @group.has_member?(current_user)
      @group.members.delete(current_user)
      notice = "You have left this group."
    elsif @group.has_admin?(current_user)
      if @group.admins.count > 1
        @group.admin.delete(current_user)
        notice = "You have left this group."
      else
        notice = "You are currently the only admin and cannot leave the group."
      end
    end

    # Then detach any logs
    current_user.logs.find_all do |log| 
      !log.badge.nil? && (log.badge.group == @group) 
    end.each do |log_to_detach|
      log_to_detach.detached_log = true
      log_to_detach.save!
    end

    redirect_to @group, :notice => notice
  end

  # DELETE /group-url/members/2, :id = 1, :user_id = 2, :type = member
  # DELETE /group-url/admins/2, :id = 1, :user_id = 2, :type = admin
  def destroy_user
    @user = User.find(params[:user_id])
    notice = "That user is not a #{params[:type]}!"
    detached_log_count = 0

    if params[:type] == 'admin' && @group.has_admin?(@user)
      @group.admins.delete(@user)
      @group.members << @user
      @group.save
      notice = "#{@user.name} has been downgraded from an admin to a member."
    elsif params[:type] == 'member' && @group.has_member?(@user)
      @group.members.delete(@user)
      @user.logs.find_all { |log| log.badge.group == @group }.each do |log_to_detach|
        log_to_detach.detached_log = true
        log_to_detach.save!
        detached_log_count += 1
      end
      notice = "#{@user.name} has been removed from the learning group members"
      notice += " and dropped from #{detached_log_count} badges" if detached_log_count > 0
      notice += "."
    end

    redirect_to @group, :notice => notice
  end

  # POST /group-url/invited_members/{email}/invitation, :type = member
  # POST /group-url/invited_admins/{email}/invitation, :type = admin
  def send_invitation
    email = params[:email].downcase
    invited_users = params[:type] == 'admin' ? 
                                    @group.invited_admins : @group.invited_members
    found_user = invited_users.detect { |u| u["email"] == email}

    if found_user
      # Query for the badges if param is included
      if found_user["badges"].blank?
        @badges, badge_ids = [], []
      else
        @badges = @group.badges.where(:url.in => found_user["badges"])
        badge_ids = @badges.map{ |b| b.id }
      end

      if params[:type] == 'admin'
        NewUserMailer.delay.group_admin_add(found_user["email"], found_user["name"], 
                                      current_user.id, @group.id, badge_ids)
      else
        NewUserMailer.delay.group_member_add(found_user["email"], found_user["name"], 
                                      current_user.id, @group.id, badge_ids)
      end
      found_user[:invite_date] = Time.now

      if !@group.save
        notice = "There was a problem updating the group, please try again later."
      else
        notice = "Learning Group invitation for #{email} has been sent."  
      end
    else
      notice = "There's no pending Learning Group invitation for #{email}."
    end

    redirect_to @group, :notice => notice
  end

  # DELETE /group-url/invited_members/{email}, :type = member
  # DELETE /group-url/invited_admins/{email}, :type = admin
  def destroy_invited_user
    email = params[:email].downcase
    invited_users = params[:type] == 'admin' ? 
                                    @group.invited_admins : @group.invited_members
    found_user = invited_users.detect { |u| u["email"] == email}

    if found_user
      invited_users.delete(found_user)
      if !@group.save
        notice = "There was a problem updating the group, please try again later."
      else
        notice = "Learning Group invitation for #{email} has been revoked."  
      end
    else
      notice = "There's no pending Learning Group invitation for #{email}."
    end

    redirect_to @group, :notice => notice
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

  # PUT /group-url/members?type=member
  # PUT /group-url/admins?type=admin
  # :emails => '"Bob Smith" <bob@example.com>, another@example.com \n yet@example.com'
  # :badges[] => ["badge-url1","badge-url2"] >> Users with be added/invited to these
  # :notify_by_email => boolean
  # State variables for output: 
  #   @group, @type, @invalid_emails, @upgraded_member_emails, @new_member_emails,
  #   @new_admin_emails, @skipped_member_emails, @skipped_admin_emails
  def create_users
    @type = params[:type] == 'admin' ? :admin : :member
    @notify_by_email = params[:notify_by_email] == "1"
    @new_admin_emails = []
    @new_member_emails = []
    @upgraded_member_emails = [] # members who were upgraded to admins
    @skipped_member_emails = [] # skipped because they were already members
    @skipped_admin_emails = [] # skipped because either...
                               # type=admin >> They are already admins
                               # type=member >> Admins cannot be down-graded

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
    
    unless valid_emails.empty?
      # query for users and build list of users that don't exist yet
      match_results = match_emails_to_users(valid_emails)
      users_to_add = match_results[:matched_users]
      emails_to_invite = match_results[:unmatched_emails]

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
                UserMailer.delay.group_admin_add(user.id, current_user.id, @group.id, badge_ids)
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
                UserMailer.delay.group_member_add(user.id, current_user.id, @group.id, badge_ids)
              end
              @new_member_emails << user.email
            end
          end
        end
      end

      # Check if the group variables need initialization
      @group.invited_admins = [] if @group.invited_admins.nil?
      @group.invited_members = [] if @group.invited_members.nil?

      # For new users: We will park them in an array of hashes on the group
      if params[:notify_by_email]
        invite_date = Time.now
      else
        invite_date = nil
      end
      emails_to_invite.each do |email|
        invited_user = {:email => email, :name => name_from_email[email], :invite_date => invite_date }
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
          NewUserMailer.delay.group_admin_add(email, name_from_email[email],
            current_user.id, @group.id, badge_ids) if @notify_by_email
        else
          if @group.has_invited_member?(email)
            @skipped_member_emails << email
          else
            @group.invited_members << invited_user
            @new_member_emails << email
            NewUserMailer.delay.group_member_add(email, name_from_email[email],
              current_user.id, @group.id, badge_ids) if @notify_by_email
          end
        end
      end
    end

    if @group.changed?
      if !@group.save
        flash[:error] = "There was a problem updating the group, please try again later."
        render 'add_users'
      end
    end
  end

private

  def find_group
    # Note: Downcase is handled by group model
    @group = Group.find(params[:id] || params[:group_id]) || not_found
    @group.log_active_user current_user # log monthly active user if applicable
    @current_user_is_admin = current_user && @group.has_admin?(current_user)
    @current_user_is_member = current_user && @group.has_member?(current_user)
    @current_user_is_owner = current_user && (@group.owner_id == current_user.id)
    @badge_list_admin = current_user && current_user.admin?
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
