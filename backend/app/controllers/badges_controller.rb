class BadgesController < ApplicationController
  
  prepend_before_action :find_badge_by_id, only: [:get, :add_endorsements]
  prepend_before_action :find_parent_records, except: [:get, :show, :edit, :update, :destroy, :entries_index, :add_learners, 
    :create_learners, :issue_form, :issue_save, :add_endorsements_form, :add_endorsements, :move, :my_index]
  prepend_before_action :find_all_records, only: [:edit, :update, :destroy, :entries_index, :add_learners, :create_learners, :issue_form, 
    :issue_save, :add_endorsements_form, :move]
  before_action :authenticate_user!, except: [:get, :show, :entries_index]
  before_action :group_owner, only: [:move]
  before_action :group_admin, only: [:new, :create, :destroy]
  before_action :can_award, only: [:issue_form, :issue_save, :add_endorsements_form, :add_endorsements]
  before_action :can_edit, only: [:edit, :update, :add_learners, :create_learners]
  before_action :set_editing_parameters, only: [:new, :edit]
  before_action :build_requirement_list, only: [:new, :edit]

  # === LIMIT-FOCUSED FILTERS === #

  before_action :can_create_badges, only: [:new, :create]
  before_action :can_create_entries, only: [:issue_form, :issue_save, :add_endorsements_form, :add_endorsements]
  before_action :group_has_bulk_tools_feature, only: [:add_endorsements_form, :add_endorsements]

  # === CONSTANTS === #

  PERMITTED_PARAMS = [:name, :url_with_caps, :summary, :info, :word_for_expert, 
    :word_for_learner, :editability, :awardability, :visibility, :image_frame, :image_icon, 
    :image_color1, :image_color2, :icon_search_text, :topic_list_text, :custom_image_key, 
    :send_validation_request_emails, :move_to_group_id]
      
  MAX_INVITATION_MESSAGE_LENGTH = 500
  EXPERT_WORDS = %w(expert master guide guru jedi)
  LEARNER_WORDS = %w(learner trainee student novice padawan)
  BADGE_VISIBILITY_OPTIONS = [
    ['<i class="fa fa-globe"></i> <strong>Public -</strong> Everyone'.html_safe, 'public'],
    ['<i class="fa fa-users"></i> <strong>Private -</strong> Only Group Members'.html_safe, 
      'private'],
    ['<i class="fa fa-eye-slash"></i> <strong>Hidden -</strong> Only Badge Members '.html_safe \
      + '&amp; Group Admins'.html_safe, 'hidden']
  ]

  # GET /?page=1
  # Returns JSON
  # This returns a list of the current user's badges in progress
  def my_index
    @page_size = APP_CONFIG['page_size_small']
    
    @page = (params[:page] || 1).to_i
    @badges = Badge.array_json(Badge.where(:id.in => current_user.learner_badge_ids).asc(:name)\
      .page(@page).per(@page_size), :api_v1, current_user: current_user, stringify_ids: true)
    
    if Badge.where(:id.in => current_user.learner_badge_ids).count > (@page_size*@page)
      @next_page = @page + 1
    else
      @next_page = nil
    end

    render json: { next_page: @next_page, items: @badges }
  end

  # GET /badges/{badge_id}
  # GET /badges/{badge_url}?parent_path={group_url}
  # Returns JSON
  # Returns badge API json
  def get
    render json: @badge.json(:api_v1, current_user: current_user)
  end

  # === RESTFUL ACTIONS === #
  # GET /group-url/badge-url
  # GET /group-url/badge-url.json
  def show
    respond_to do |format|
      format.any(:html, :js) do # show.html.erb
        find_all_records
        @first_view_after_issued = @log && @log.has_flag?('first_view_after_issued')
        @new_expert_logs = @badge.new_expert_logs
        @show_emails = (@current_user_is_admin || @badge_list_admin) && params[:show_emails]

        # Get paginated versions of member and expert logs
        @page_learners = params[:pl] || 1
        @page_experts = params[:pe] || 1
        @page_size = params[:page_size] || APP_CONFIG['page_size_small']
        @learner_logs = @badge.learner_logs.page(@page_learners).per(@page_size)
        @expert_logs = @badge.expert_logs.page(@page_experts).per(@page_size)
        @requirements = @badge.requirements
        @requirements_json_clone = @badge.requirements_json_clone

        # Add a filter the expert and learner logs if this user isn't an admin or awarder
        # NOTE: This won't show the current user their own name, which is potentially confusing,
        #       but the only truly non-confusing thing would be to modify the log partial with a 
        #       special message which is too time-consuming for now, so I'm leaving it.
        if !@current_user_is_admin && !@badge_list_admin && !@can_award_badge
          @learner_logs = @learner_logs.where(show_on_badge: true)
          @expert_logs = @expert_logs.where(show_on_badge: true)
        end

        # Configure the badge settings if needed
        @badge_visibility_options = BADGE_VISIBILITY_OPTIONS
        if @current_user_is_admin || @badge_list_admin
          @badge_editability_options = [
            ["Badge #{@badge.Experts} & Group Admins", 'experts'],
            ["Only Group Admins", 'admins']
          ]
          @badge_awardability_options = @badge_editability_options

          @send_email_options = [
            ['Let each awarder opt-out (recommended)', true],
            ['Send no emails to anyone', false]
          ]
        end

        # Get current values of group membership settings
        if @current_user_is_admin || @current_user_is_member
          @group_show_on_badges = current_user.get_group_settings_for(@group)['show_on_badges']
          @group_show_on_profile = current_user.get_group_settings_for(@group)['show_on_profile']
        end
      end
      format.json do 
        @group = Group.find(params[:group_id]) || not_found
        @badge = @group.badges.find_by(url: (params[:id] || params[:badge_id]).to_s.downcase) \
          || not_found
        return_value = @badge.as_json(filter_user: current_user)

        # If this is a private group we need to filter out user-related keys
        if @group.has?(:privacy) && !@badge_list_admin && !@current_user_is_admin \
            && !@current_user_is_member
          return_value.delete 'experts'
          return_value.delete 'learners'
        end

        render json: return_value
      end
    end
  end

  # GET /group-url/badges/new
  # GET /group-url/badges/new.json
  def new
    @badge = Badge.new(group: @group)
    @allow_url_editing = true

    # Create the carrierwave direct uploader
    @uploader = Badge.new.direct_custom_image
    @uploader.success_action_redirect = image_key_url
    
    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @badge, filter_user: current_user }
    end
  end

  # GET /group-url/badge-url/edit
  def edit
    @allow_url_editing = (@badge.expert_logs.length < 2)

    # Create the carrierwave direct uploader
    @uploader = Badge.new.direct_custom_image
    @uploader.success_action_redirect = image_key_url
  end

  # POST /group-url/badges
  # POST /group-url/badges.json
  def create
    # First build the badge as normal to make sure that it's valid
    @badge = Badge.new(badge_params)
    @badge.group = @group
    @badge.visibility = 'private' if @group.has?(:privacy)
    @badge.creator = current_user
    @badge.current_user = current_user
    @badge.current_username = current_user.username
    @requirement_list = params[:rl]

    if @badge.valid?
      poller_id = Badge.create_async(@group.id, current_user.id, badge_params, 
        @requirement_list)
      
      # Then redirect to the group with the poller passed
      redirect_to group_path(@group, badge_poller: poller_id), 
        notice: "<i class='fa fa-refresh fa-spin'></i> ".html_safe + \
          "The '#{@badge.name}' badge is being created..."
    else
      set_editing_parameters
      @allow_url_editing = true;

      # Create the carrierwave direct uploader
      @uploader = @badge.direct_custom_image
      @uploader.success_action_redirect = image_key_url

      flash[:error] = "There was an error creating the badge."
      render action: "new"
    end
  end

  # PUT /group-url/badge-url
  # PUT /group-url/badge-url?modal=true >> Redirects back to group with flash error on save failure
  # PUT /group-url/badge-url.json
  def update
    # First build the badge as normal to make sure that it's valid
    @badge.current_user = current_user
    @badge.current_username = current_user.username
    @badge.assign_attributes(badge_params)
    @requirement_list = params[:rl]
    
    if @badge.valid?
      poller_id = @badge.update_async(current_user.id, badge_params, @requirement_list)
      
      # Then redirect to the full page poller UI
      redirect_to poller_path(poller_id)
    else
      set_editing_parameters
      build_requirement_list if @requirement_list.blank? # rebuild from scratch if needed
      @allow_url_editing = @badge.expert_logs.length < 2;

      # Create the carrierwave direct uploader
      @uploader = Badge.new.direct_custom_image
      @uploader.success_action_redirect = image_key_url

      if params[:modal]
        flash[:error] = "There was a problem updating the badge, try again later.\n" \
          + "Error Text: #{@badge.errors}"
        render action: "show"
      else
        render action: "edit"
      end
    end
  end

  # DELETE /group-url/badge-url
  # DELETE /group-url/badge-url.json
  def destroy
    @badge.destroy

    respond_to do |format|
      format.html { redirect_to @group, notice: "The badge has been deleted." }
      format.json { head :no_content }
    end
  end

  # === NON-RESTFUL ACTIONS === #

  # Accepts page parameters: page, page_size
  # GET /group-url/badge-url/entries
  # GET /group-url/badge-url/entries.json
  def entries_index
    # Grab the current page of entries
    @page = params[:page] || 1
    @page_size = params[:page_size] || APP_CONFIG['page_size_normal']
    # RETIRING THIS PAGE FOR NOW
    # @entries = @badge.entries(current_user, nil, @page, @page_size)
    @entries = []

    respond_to do |format|
      format.html # entries_index.html.erb
      format.json { render json: @badge, filter_user: current_user }
    end
  end

  # GET /group-url/badge-url/learners/add
  # GET /group-url/badge-url/learners/add.json
  # :usernames => array_of_usernames_to_add[]
  # @learner_list = array of {
  #   :user => user
  #   :disabled => true_if_already_added_to_badge
  def add_learners
    @learner_list = []
    @already_added_users = @badge.logs.map{ |log| log.user unless log.detached_log } 

    [@group.members, @group.admins].flatten.sort_by { |user| user.name }.each do |user|
      @learner_list << {
        user: user,
        disabled: @already_added_users.include?(user)
      }
    end

    @group_is_blank = (@learner_list.count <= 1)
  end

  # POST /group-url/badge-url/learners
  # POST /group-url/badge-url/learners.json
  # :usernames[] => array_of_usernames_to_add[]
  # :notify_by_email => boolean
  # :invitation_message => String
  def create_learners
    @notify_by_email = params[:notify_by_email] == "1"
    new_learner_count = 0
    new_learner_log = nil

    # Get the invitation message and truncate it if needed
    @invitation_message = params[:invitation_message]
    if !@invitation_message.blank? && (@invitation_message.length > MAX_INVITATION_MESSAGE_LENGTH)
      @invitation_message = @invitation_message.first(MAX_INVITATION_MESSAGE_LENGTH-3) + '...'
    end

    params[:usernames].each do |username|
      user = User.find(username.to_s.downcase) rescue nil
      if user && !user.learner_of?(@badge) && !user.expert_of?(@badge)
        new_learner_log = @badge.add_learner(user, update_user_async: true)
        new_learner_count += 1
        
        if @notify_by_email && !user.email_inactive
          UserMailer.delay.log_new(user.id, current_user.id, @group.id, @badge.id, \
            new_learner_log.id, @invitation_message)
        end
      end
    end unless params[:usernames].blank?

    respond_to do |format|
      format.html { redirect_to group_badge_path(@group, @badge)+'#learners', 
        notice: "#{new_learner_count} learners were added to the badge." } 
      format.json { head :no_content }
    end
  end

  # GET /group-url/badge-url/issue
  # Accepts email param
  def issue_form
    @email = params[:email]
    @summary = ''
    @body = ''
    @member_list = []
    existing_expert_emails = @badge.expert_logs.map{ |log| log.user.email }

    [@group.members, @group.admins].flatten.sort_by { |user| user.name }.each do |user|
      @member_list << [user.email, user.name] unless existing_expert_emails.include? user.email
    end

    @member_list_is_blank = (@member_list.count < 1)
  end

  # POST /group-url/badge-url/issue?email=a@b.com&summary=text&body=&text
  def issue_save
    @email = params[:email].to_s.downcase
    @summary = params[:summary]
    @body = params[:body]
    @member_list = []

    # NOTE FOR IMPROVEMENT: If the threshold is above one the flash messages should be more clear.

    if @email.blank?
      flash[:error] = "You must enter the email of the person who will receive the badge."
      render 'issue_form'
    elsif @summary.blank?
      flash[:error] = "You must enter a validation summary."
      render 'issue_form'
    elsif @summary.length > Entry::MAX_SUMMARY_LENGTH
      flash[:error] = "The summary can't be longer than #{Entry::MAX_SUMMARY_LENGTH} characters. "\
        + "If you need more space you can use the body text."
      render 'issue_form'
    else
      user = User.find_by(email: @email) rescue nil

      if user.nil?
        # add them to the group invited members (but be sure not to create a dupe)
        if @group.has_invited_member? @email
          found_user = @group.invited_members.detect { |u| u["email"] == @email}
          found_user[:validations] = [] unless found_user.include? :validations
          found_user[:validations] << { badge: @badge.url, summary: @summary, body: @body, 
            user: current_user._id }
        elsif @group.has_invited_admin? @email
          found_user = @group.invited_admins.detect { |u| u["email"] == @email}
          found_user[:validations] = [] unless found_user.include? :validations
          found_user[:validations] << { badge: @badge.url, summary: @summary, body: @body, 
            user: current_user._id }
        elsif !@group.can_add_members?
          flash[:error] = "This group is full and cannot accept new members."
          render 'issue_form'
        else
          @group.invited_members << { email: @email, invite_date: Time.now, 
            validations: [{ badge: @badge.url, summary: @summary, body: @body, 
              user: current_user._id }] }
        end

        # Save the changes to the group and send the email (if not blocked)
        @group.save!
        if User.get_inactive_email_list.include? @email
          redirect_to [@group, @badge], 
            notice: "The badge has been awarded, but the recipient's email address "\
            + "(#{@email}) is currently blocked so they will not receive an email notification. " \
            + "They will still receive the badge automatically once they create a Badge List " \
            + "account. Please reach out to support with any questions."
        else
          NewUserMailer.delay.badge_issued(@email, nil, current_user.id, @group.id, @badge.id)
          redirect_to [@group, @badge], 
            notice: "The badge has been awarded and the recipient has been notified "\
            + "at #{@email}. As soon as the recipient creates a Badge List account, they will " \
            + "be able to accept the badge."
        end
      elsif user.expert_of? @badge
        flash[:error] = "#{user.name} is already a badge expert! " \
          + "You can't issue them the badge twice."
        render 'issue_form'
      elsif user.learner_of? @badge
        # add a validation
        log = @badge.logs.find_by(user: user)
        log.add_validation current_user, @summary, @body, true
        redirect_to [@group, @badge], notice: "#{user.name} has been issued the badge and " \
          + "upgraded from a learner to an expert."
      elsif user.member_of?(@group) || user.admin_of?(@group)
        # create log and add validation
        log = @badge.add_learner user
        log.add_validation current_user, @summary, @body, true
        redirect_to [@group, @badge], notice: "#{user.name} has been issued the badge and " \
          + "is now a badge expert."
      elsif !@group.can_add_members?
        flash[:error] = "This group is full and cannot accept new members."
        render 'issue_form'
      else
        # create membership, log and validation
        @group.members << user
        @group.save
        log = @badge.add_learner user
        log.add_validation current_user, @summary, @body, true
        if user.email_inactive
          redirect_to [@group, @badge], notice: "#{user.name} has been issued the badge and " \
            + "added as a group member. (Note: The user's email address is currently blocked " \
            + "so they will not receive any email notifications.)"
        else
          redirect_to [@group, @badge], notice: "#{user.name} has been issued the badge and " \
            + "added as a group member."
        end

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

  # GET /group-url/badge-url/endorsements/add
  # Displays the polymer app which displays the add endorsement UI
  def add_endorsements_form
    render_polymer_app("Bulk Award - #{@badge.name} - Badge List")
  end

  # POST /badges/id/endorsements
  # JSON Only
  # This is a json wrapper for Badge.bulk_award, which awards the badge in bulk.
  # Accepts parameters:
  # - request body = JSON array of endorsement objects with following keys (*=required): email*, summary*, body
  # - send_emails_to_new_users query param = Boolean (defaults to false)
  def add_endorsements
    @max_list_size = APP_CONFIG['max_import_list_size']
    @validations = JSON.parse(request.body.read)
    @send_emails_to_new_users = (params[:send_emails_to_new_users] == 'true') || (params[:send_emails_to_new_users].to_s == '1')

    respond_to do |format|
      format.json do
        if (@validations.class == Array) && !@validations.blank?
          if @validations.count > @max_list_size
            render json: { error_message: "The items parameter cannot contain more than #{@max_list_size} items." }, status: :bad_request
          else
            @poller = Poller.new
            @poller.progress = 0
            @poller.waiting_message = 'Adding endorsements...'
            @poller.save

            Badge.delay(retry: false).bulk_award(@badge.id, current_user.id, @validations, @send_emails_to_new_users, @poller.id)

            render json: { poller_id: @poller.id.to_s }
          end
        else
          render json: { error_message: 'The items parameter is required and must be a non-blank list.' }, status: :bad_request
        end
      end
    end
  end

  # PUT /group/badge/move?badge[move_to_group_id]=abc123
  # Basically this is the same as the update function but focused on setting move to group field
  def move
    @badge.move_to_group_id = params[:badge][:move_to_group_id]
    
    if @badge.save
      @group = @badge.group
      redirect_to [@group, @badge], 
        notice: "The badge was successfully moved to the '#{@group.name}' group. " \
        + "It may take another few minutes for all of the group memberships to be moved over."
        
    else
      flash[:error] = @badge.errors.messages[:move_to_group_id].first
      render action: "show"
    end
  end

private

  # Used by temporary API action(s). 
  # Note: The id parameter can either be a record id or a string of the format `group-url.badge-url`. Refer to `Badge.find()` for more info.
  def find_badge_by_id
    if (params[:parent_path])
      @group = Group.find(params[:parent_path]) || not_found
      @badge = @group.badges.where(url: params[:id].to_s.downcase).first || not_found
    else
      @badge = Badge.find(params[:id]) || not_found
      @group = @badge.group
    end
  end

  def find_parent_records
    @group = Group.find(params[:group_id]) || not_found
    @current_user_is_owner = current_user && @group.owner_id \
      && (current_user.id == @group.owner_id)
    @current_user_is_admin = current_user && current_user.admin_of?(@group)
    @current_user_is_member = current_user && current_user.member_of?(@group)
    @badge_list_admin = current_user && current_user.admin?
    @can_edit_badge = @current_user_is_admin || @badge_list_admin
    @can_award_badge = @current_user_is_admin

    # Set current group (for analytics) only if user is logged in and an admin
    @current_user_group = @group if @current_user_is_admin
  end

  def find_all_records
    find_parent_records

    @badge = @group.badges.find_by(url: (params[:id] || params[:badge_id]).to_s.downcase) \
      || not_found
    @current_user_is_expert = current_user && current_user.expert_of?(@badge)
    @current_user_is_learner = current_user && current_user.learner_of?(@badge)
    if @current_user_is_learner || @current_user_is_expert
      # Confirm that we can really query their log (edge cases can happen sometimes)
      @log = @badge.logs.find_by(user: current_user) rescue nil
      if @log
        @requirements_counts = @log.requirements_counts
      else
        @current_user_is_expert, @current_user_is_learner = false, false
      end
    end
    @can_edit_badge = @can_edit_badge \
      || ((@badge.editability == 'experts') && @current_user_is_expert)
    @can_award_badge = @can_award_badge \
      || ((@badge.awardability == 'experts') && @current_user_is_expert)

    @can_see_badge = @current_user_is_admin || @badge_list_admin || @current_user_is_expert \
      || @current_user_is_learner || (@badge.visibility == 'public') \
      || ((@badge.visibility == 'private') && @current_user_is_member)

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

  def group_admin
    unless @current_user_is_admin || @badge_list_admin
      flash[:error] = "You must be a group admin to do that!"
      redirect_to @group
    end 
  end

  def group_owner
    unless @current_user_is_owner || @badge_list_admin
      flash[:error] = "You must be the group owner to do that!"
      redirect_to @group
    end 
  end

  def can_award
    # Manually set this if this was initialized by find_badge_by_id (and the @-booleans aren't set)
    @can_award_badge ||= current_user.present? \
      && (current_user.admin_of?(@group) || ((@badge.awardability == 'experts') && current_user.expert_of?(@badge)))

    unless @can_award_badge
      flash[:error] = "You do not have permission to award this badge."
      redirect_to [@group, @badge]
    end 
  end

  def can_edit
    unless @can_edit_badge
      flash[:error] = "You do not have permission to edit this badge."
      redirect_to [@group, @badge]
    end 
  end

  def can_create_badges
    if @group.disabled?
      flash[:error] = "New badges cannot be created in a disabled group."
      redirect_to @group
    end
  end

  def can_create_entries
    if @group.disabled?
      flash[:error] = "This badge cannot be awarded to new people while the group is inactive."
      redirect_to @group
    end
  end

  def group_has_bulk_tools_feature
    if !@group.has?(:bulk_tools)
      @error_message = 'This group does not have the bulk tools feature.'

      respond_to do |format|
        format.json do
          render json: { error_message: @error_message }, status: :bad_request
        end
        format.html do
          flash[:error] = @error_message
          redirect_to [@group, @badge]
        end
      end
    end
  end

  def set_editing_parameters
    # Initialize the badge requirement list and related info
    @tag_format_map = {}
    @tag_format_options_string = ''
    Tag::FORMAT_VALUES.each do |format_string|
      @tag_format_map[format_string] = {
        icon: Tag.format_icon(format_string),
        text: format_string.capitalize,
      }
      
      if format_string == 'any'
        human_readable_format_string = 'Any Format'
      else
        human_readable_format_string = format_string.capitalize
      end

      if (format_string != 'file') || @group.has?(:file_uploads)
        @tag_format_options_string += \
          "<option value='#{format_string}'>#{human_readable_format_string}</option>"
      end
    end
    @tag_privacy_map = {}
    @tag_privacy_options_string = ''
    Tag.privacy_values(@group.has?(:privacy)).each do |privacy_string|
      @tag_privacy_map[privacy_string] = {
        icon: Tag.privacy_icon(@group.has?(:privacy), privacy_string),
        name: privacy_string.capitalize,
        text: Tag.privacy_text(@group.has?(:privacy), privacy_string)
      }
      @tag_privacy_options_string += \
        "<option value='#{privacy_string}'>#{privacy_string.capitalize} " \
        + "(#{Tag.privacy_text(@group.has?(:privacy), privacy_string).capitalize})</option>"
    end
  end

  # Build from badge
  def build_requirement_list
    @requirement_list = (@badge) ? @badge.build_requirement_list : '[]'
  end

  def badge_params
    params.require(:badge).permit(PERMITTED_PARAMS)
  end

end
