class GroupsController < ApplicationController

  # === FILTERS === #

  # RESTful Actions >> :index, :show, :new, :edit, :create, :update, :destroy
  # Non-RESTful Actions >> :leave, :destroy_user, :destroy_invited_user, 
  #                        :add_users, :create_users

  before_filter :authenticate_user!, except: [:show]
  before_filter :group_member_or_admin, only: [:leave]
  before_filter :group_admin, only: [:edit, :update, :destroy,
                                     :destroy_user, :destroy_invited_user,
                                     :add_users, :create_users]

  # === CONSTANTS === #

  GROUP_TYPE_OPTIONS = [
    ['<b>Open</b> - All activity is public, membership is open'.html_safe,
      'open'],
    ['<b>Closed</b> - All activity is public, membership is closed'.html_safe,
      'closed'],
    ['<b>Private</b> - Hidden group, private activity, membership is closed'.html_safe,
      'private']
  ]

  # === RESTFUL ACTIONS === #
  
  # GET /groups
  # GET /groups.json
  def index
    current_user.reload
    @groups = []

    respond_to do |format|
      format.html do # index.html.erb
        @groups << current_user.admin_of unless current_user.admin_of.empty?
        @groups << current_user.member_of unless current_user.member_of.empty?
      end
      format.json do
        @return_hash = {
          :admin_of => current_user.admin_of,
          :member_of => current_user.member_of,
          :created_groups => current_user.created_groups
        }
        render json: @return_hash
      end
    end
  end

  # GET /groups/1
  # GET /groups/1.json
  def show
    @group = Group.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @group }
    end
  end

  # GET /groups/new
  # GET /groups/new.json
  def new
    @group = Group.new
    @group_type_options = GROUP_TYPE_OPTIONS

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @group }
    end
  end

  # GET /groups/1/edit
  def edit
      @group = Group.find(params[:id])
      @group_type_options = GROUP_TYPE_OPTIONS
  end

  # POST /groups
  # POST /groups.json
  def create
    @group = Group.new(params[:group])
    @group.creator = current_user
    @group_type_options = GROUP_TYPE_OPTIONS

    respond_to do |format|
      if @group.save
        format.html { redirect_to @group, 
                      notice: 'Learning Group was successfully created.' }
        format.json { render json: @group, status: :created, location: @group }
      else
        format.html { render action: "new" }
        format.json { render json: @group.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /groups/1
  # PUT /groups/1.json
  def update
    @group = Group.find(params[:id])

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

  # DELETE /groups/1
  # DELETE /groups/1.json
  def destroy
    @group = Group.find(params[:id])
    @group.destroy

    respond_to do |format|
      format.html { redirect_to root_url }
      format.json { head :no_content }
    end
  end

  # === NON-RESTFUL ACTIONS === #

  # DELETE /groups/1/leave
  def leave
    @group = Group.find(params[:id])
    notice = "You aren't a member of this Learning Group, so you can't leave it."

    if @group.has_member?(current_user)
      @group.members.delete(current_user)
      notice = "You have left this group."
    elsif @group.has_admin?(current_user)
      @group.admin.delete(current_user)
      notice = "You have left this group."
    end

    redirect_to @group, :notice => notice
  end

  # DELETE /groups/1/members/2, :id = 1, :user_id = 2, :type = member
  # DELETE /groups/1/admins/2, :id = 1, :user_id = 2, :type = admin
  def destroy_user
    @group = Group.find(params[:id])
    @user = User.find(params[:user_id])
    notice = "That user is not a #{params[:type]}!"

    if params[:type] == 'admin' && @group.has_admin?(@user)
      @group.admins.delete(@user)
      notice = "#{@user.name} has been removed from the Learning Group admins."
    elsif params[:type] == 'member' && @group.has_member?(@user)
      @group.members.delete(@user)
      notice = "#{@user.name} has been removed from the Learning Group members."
    end

    redirect_to @group, :notice => notice
  end

  # DELETE /groups/1/invited_members/{email}, :type = member
  # DELETE /groups/1/invited_admins/{email}, :type = admin
  def destroy_invited_user
    @group = Group.find(params[:id])
    email = params[:email].downcase
    invited_users = params[:type] == 'admin' ? 
                                    @group.invited_admins : @group.invited_users
    found_user = invited_users.detect { |u| u[:email] == email}

    if found_user
      invited_users.delete(found_user)
      notice = "Learning Group invitation for #{email} has been revoked."
    else
      notice = "There's no pending Learning Group invitation for #{email}."
    end

    redirect_to @group, :notice => notice
  end


  # GET /groups/1/members/add?type=member
  # GET /groups/1/admins/add?type=admin
  def add_users
    @group = Group.find(params[:id])
    @type = params[:type] == 'admin' ? :admin : :member
  end

  # PUT /groups/1/members?type=member
  # PUT /groups/1/admins?type=admin
  # :emails => '"Bob Smith" <bob@example.com>, another@example.com \n yet@example.com'
  # :notify_by_email => boolean
  # State variables for output: 
  #   @group, @type, @invalid_emails, @upgraded_member_emails, @new_member_emails,
  #   @new_admin_emails, @skipped_member_emails, @skipped_admin_emails
  def create_users
    @group = Group.find(params[:id])
    @type = params[:type] == 'admin' ? :admin : :member
    @new_admin_emails = []
    @new_member_emails = []
    @upgraded_member_emails = [] # members who were upgraded to admins
    @skipped_member_emails = [] # skipped because they were already members
    @skipped_admin_emails = [] # skipped because either...
                               # type=admin >> They are already admins
                               # type=member >> Admins cannot be down-graded

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
        if @type == :admin
          users_to_add.each do |user|
            if group.has_admin?(user)
              skipped_admin_emails << user.email
            else
              group.admins << user
              # fixme: Add function to send an email
              if group.has_member?(user)
                group.members.delete(user)
                upgraded_member_emails << user.email
              else
                new_admin_emails << user.email
              end
            end
          end
        else
          users_to_add.each do |user|
            if group.has_member?(user)
              skipped_member_emails << user.email
            elsif group.has_admin?(user)
              skipped_admin_emails << user.email
            else
              group.members << user
              # fixme: Add function to send an email
              new_member_emails << user.email
            end
          end
        end
      end

      # For new users: We will park them in an array of hashes on the group
      if params[:notify_by_email]
        invite_date = Time.now
      else
        invite_date = nil
      end
      emails_to_invite.each do |email|
        if @type == :admin
          group.invited_admins << {
            :email => email,
            :name => name_from_email[email],
            :invite_date => invite_date
          }
          new_admin_emails << email
          # fixme: Add function to send an email
        else
          group.invited_members << {
            :email => email,
            :name => name_from_email[email],
            :invite_date => invite_date
          }
          new_member_emails << email
          # fixme: Add function to send an email
        end
      end
    end
  end

  private

    # === BEFORE FILTERS === #

    def group_admin
      @group = Group.find(params[:id])
      unless @group.has_admin?(current_user)
        flash[:error] = "You must be an admin of #{@group.name} to do that!"
        redirect_to @group
      end 
    end

    def group_member_or_admin
      @group = Group.find(params[:id])
      if !@group.has_member?(current_user) && !@group.has_admin?(current_user)
        flash[:error] = "You must be a member or admin of #{@group.name} to do that!"
        redirect_to @group
      end
    end

end
