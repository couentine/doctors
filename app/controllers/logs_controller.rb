class LogsController < ApplicationController
  include UsersHelper
  
  prepend_before_filter :find_parent_records, except: [:show, :edit, :update, :destroy]
  prepend_before_filter :find_all_records, only: [:show, :edit, :update, :destroy]
  before_filter :authenticate_user!, only: [:edit, :create, :update, :destroy]
  before_filter :log_owner, only: [:edit, :destroy]
  before_filter :group_admin_or_log_owner, only: [:update]

  # === RESTFUL ACTIONS === #

  # GET /group-url/badge-url/u/username
  # GET /group-url/badge-url/u/username.json
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @log }
    end
  end

  # GET /group-url/badge-url/u/username/edit
  def edit
    # Nothing to do (find_records loads the log)
  end

  # POST /group-url/badge-url/logs
  # POST /group-url/badge-url/logs.json
  # This action allows the CURRENT_USER to join the badge
  # It will also add them to the group if needed or present an error message if
  # they do not have the appropriate permissions.
  def create
    log_already_exists = @current_user_is_expert || @current_user_is_learner
    needs_to_join_group = !@current_user_is_admin && !@current_user_is_member
    allowed_to_join_badge = @current_user_is_admin || @current_user_is_member || @group.open?
    is_error = false
    message = ''

    if allowed_to_join_badge
      if needs_to_join_group # group is open so we'll add the user to the members now
        @group.members << current_user
        if @group.save
          message = 'You have joined both the learning group and the badge. Welcome!'
        else
          message = 'An error occured while trying to add you to the learning group and badge.'
          is_error = true
        end
      elsif log_already_exists
        message = 'You are already a member of this badge.'
      else
        message = 'Welcome to the badge!'
      end
      @log = @badge.add_learner(current_user) # retreive their existing badge OR create new one
      is_error = @log.new_record?
      message = 'An error occured while trying to create a learning log for you.' if is_error
    else
      @log = Log.new
      message = 'You must be a member of the group to join this badge.'
      @log.errors.add(:base, message)
      is_error = true
    end

    respond_to do |format|
      if is_error
        format.html { redirect_to [@group, @badge], 
          notice: message }
        format.json { render json: @log.errors, status: :unprocessable_entity }
      else
        format.html { redirect_to [@group, @badge, @log], notice: message }
        format.json { render json: @log, status: :created, location: [@group, @badge, @log] }
      end
    end
  end

  # PUT /group-url/badge-url/u/username
  # PUT /group-url/badge-url/u/username.json
  def update
    @log.current_user = current_user
    @log.current_username = current_user.username

    respond_to do |format|
      if @log.update_attributes(params[:log])
        format.html { redirect_to [@group, @badge, @log], 
          notice: 'Learning log was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @log.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /group-url/badge-url/u/username
  # DELETE /group-url/badge-url/u/username.json
  def destroy
    @log.destroy
    if @belongs_to_current_user
      notice = "You are no longer a member of this badge."
    else
      notice = "#{@user.name} is no longer a member of the badge."
    end

    respond_to do |format|
      format.html { redirect_to [@group, @badge], notice: notice }
      format.json { head :no_content }
    end
  end

private

  def find_parent_records
    @group = Group.find(params[:group_id])
    @badge = @group.badges.find_by(url: params[:badge_id].to_s.downcase)
    @current_user_is_admin = current_user.admin_of?(@group)
    @current_user_is_member = current_user.member_of?(@group)
    @current_user_is_expert = current_user.expert_of?(@badge)
    @current_user_is_learner = current_user.learner_of?(@badge)
  end

  def find_all_records
    find_parent_records

    @user = User.find(params[:id].to_s.downcase) # find user by username
    @log = @user.logs.find_by(badge: @badge)
    @belongs_to_current_user = (@user == current_user)
  end

  def log_owner
    unless @belongs_to_current_user
      flash[:error] = "That action is restricted to the log owner."
      redirect_to [@group, @badge, @log]
    end
  end

  def group_admin_or_log_owner
    unless @current_user_is_admin || @belongs_to_current_user
      flash[:error] = "That action is restricted to group admins or the log owner."
      redirect_to [@group, @badge, @log]
    end
  end

end
