class LogsController < ApplicationController
  prepend_before_action :find_parent_records, except: [:show, :edit, :update, :destroy]
  prepend_before_action :find_all_records, only: [:show, :edit, :update, :destroy, :retract, 
    :unretract]
  before_action :authenticate_user!, only: [:create, :edit, :update, :destroy, :retract, :unretract]
  before_action :log_owner, only: [:edit, :destroy]
  before_action :group_admin_or_log_owner, only: [:update]
  before_action :can_retract, only: [:retract, :unretract]

  # === RESTFUL ACTIONS === #

  # Accepts page parameters: page, page_size
  # GET /group-url/badge-url/u/username
  # GET /group-url/badge-url/u/username.json?f=ob1
  # GET /group-url/badge-url/u/username.embed => Shows iframe-friendly version
  def show
    @validations = @log.validations

    @presentation_format = params[:f]
    @first_view_after_issued = @current_user_is_log_owner \
      && @log.has_flag?('first_view_after_issued')
    
    if @log.retracted
      # We can't just crawl through the field because it's only an id not a relationship
      @retracted_by = User.find(@log.retracted_by) rescue nil
    end

    if @presentation_format == 'ob1'
      if @log.issue_status == 'retracted'
        respond_to do |format|
          format.json { render json: { revoked: true }, status: :gone }
        end
      elsif @log.issue_status == 'issued'
        respond_to do |format|
          format.json { render json: @log }
        end
      else
        respond_to do |format|
          format.json { head :not_found }
        end
      end
    else
      if @first_view_after_issued
        @log.clear_flag 'first_view_after_issued'
        @log.timeless.save
      end

      respond_to do |format|
        format.html do
          @requirements = @badge.requirements
          @requirements_json_clone = @badge.requirements_json_clone

          # Now calculate whether at least one item has been submitted for each requirement
          # NOTE: We save a query by passing in the existing @requirements variable.
          @all_requirements_complete = @log.all_requirements_complete(@requirements)

          # Get current values of group membership settings
          if @current_user_is_admin || @current_user_is_member
            @group_show_on_badges = current_user.get_group_settings_for(@group)['show_on_badges']
            @group_show_on_profile = current_user.get_group_settings_for(@group)['show_on_profile']
          end
        end
        format.embed { render layout: 'embed' }
        format.json { render json: @log, filter_user: current_user }
      end
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
          message = 'You have joined both the group and the badge. ' \
            + 'The next step is to begin submitting evidence below.'

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
          message = 'An error occured while trying to add you to the group and badge.'
          is_error = true
        end
      elsif log_already_exists
        message = 'Unfortunately, you can only join a badge once.'
      else
        message = 'Welcome to the badge! The next step is to begin submitting evidence below.'
      end
      
      if !is_error
        @log = @badge.add_learner(current_user) # retreive their existing badge OR create new one
        is_error = @log.new_record?
        if is_error
          message = 'An error occured while trying to create a badge portfolio for you.' 
        elsif !current_user.email_inactive
          UserMailer.delay.log_new(current_user.id, current_user.id, @group.id, @badge.id, @log.id)
        end
      end
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
        format.html { redirect_to [@group, @badge], notice: message }
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
      if @log.update_attributes(log_params)
        format.html { redirect_to [@group, @badge, @log], 
          notice: "#{@badge.progress_log.capitalize} was successfully updated." }
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
    if @current_user_is_log_owner
      notice = "You are no longer a member of this badge."
    else
      notice = "#{@user.name} is no longer a member of the badge."
    end

    respond_to do |format|
      format.html { redirect_to [@group, @badge], notice: notice }
      format.json { head :no_content }
    end
  end

  # === NON-RESTFUL ACTIONS === #

  # POST /group-url/badge-url/u/username/retract
  # This action will set call the log retraction method.
  def retract
    if @log.retracted
      @notice = "#{@log.user_name}'s badge has already been retracted."
    else
      @log.retracted = true
      if @log.add_retraction current_user
        @notice = "The badge has been retracted from #{@log.user_name}."
      else
        @notice = "There was a problem retracting the badge from #{@log.user_name}, please try " \
          + "again later."
      end
    end

    respond_to do |format|
      format.html { redirect_to [@group, @badge, @log], notice: @notice }
      format.json { render json: @notice }
    end
  end

  # POST /group-url/badge-url/u/username/unretract
  # This action will set call the log clear retraction method.
  def unretract
    if !@log.retracted
      @notice = "You can't clear the #{@log.user_name}'s badge retraction, because it's not " \
        + "retracted."
    else
      @log.retracted = false
      if @log.clear_retraction
        @notice = "The badge retraction has been cleared for #{@log.user_name}."
      else
        @notice = "There was a problem claering the badge for #{@log.user_name}, please try " \
          + "again later."
      end
    end

    respond_to do |format|
      format.html { redirect_to [@group, @badge, @log], notice: @notice }
      format.json { render json: @notice }
    end
  end

private

  def find_parent_records
    @group = Group.find(params[:group_id].to_s.downcase) || not_found
    @badge = @group.badges.find_by(url: params[:badge_id].to_s.downcase) || not_found
    @current_user_is_admin = current_user && current_user.admin_of?(@group)
    @current_user_is_member = current_user && current_user.member_of?(@group)
    @current_user_is_expert = current_user && current_user.expert_of?(@badge)
    @current_user_is_learner = current_user && current_user.learner_of?(@badge)
    @badge_list_admin = current_user && current_user.admin?

    # Set current group (for analytics) only if user is logged in and an admin
    @current_user_group = @group if @current_user_is_admin

    # Define permission variables
    @can_edit_badge = @current_user_is_admin || @badge_list_admin \
      || ((@badge.editability == 'experts') && @current_user_is_expert)
    @can_award_badge = @current_user_is_admin \
      || ((@badge.awardability == 'experts') && @current_user_is_expert)
    @can_retract = @badge_list_admin || @current_user_is_admin \
      || (current_user && (@badge.creator_id == current_user.id))

    # Define badge terminology shortcuts
    @expert = @badge.expert
    @experts = @badge.experts
    @Expert = @badge.Expert
    @Experts = @badge.Experts
    @learner = @badge.learner
    @learners = @badge.learners
    @Learner = @badge.Learner
    @Learners = @badge.Learners
    @show_progress = @badge.tracks_progress?
  end

  def find_all_records
    find_parent_records

    @user = User.find(params[:id].to_s.downcase) || not_found # find user by username
    @log = @user.logs.find_by(badge: @badge) || not_found
    @current_user_is_log_owner = current_user && (@user == current_user)
    if @current_user_is_log_owner || @badge_list_admin
      @show_sharing = (@log.issue_status == 'issued')
    end
    if current_user
      @current_user_log = current_user.logs.find_by(badge: @badge) rescue nil
      @validation = current_user.created_entries.find_by(log: @log, type: 'validation') rescue nil
    end
  end

  def log_owner
    unless @current_user_is_log_owner || @badge_list_admin
      flash[:error] = "That action is restricted to the log owner."
      redirect_to [@group, @badge, @log]
    end
  end

  def group_admin_or_log_owner
    unless @current_user_is_admin || @current_user_is_log_owner || @badge_list_admin
      flash[:error] = "That action is restricted to group admins or the log owner."
      redirect_to [@group, @badge, @log]
    end
  end

  def can_retract
    unless @can_retract
      flash[:error] = "Only group admins and the badge creator are able to retract the badge."
      redirect_to [@group, @badge, @log]
    end
  end

  def log_params
    params.require(:log).permit(:show_on_profile, :show_on_badge, :detached_log, :date_started, 
      :date_requested, :date_withdrawn, :date_sent_to_backpack, :wiki, 
      :receive_validation_request_emails)
  end

end