class BadgesController < ApplicationController
  
  prepend_before_filter :find_parent_records, except: [:show, :edit, :update, :destroy, 
    :entries_index, :add_learners, :create_learners, :issue_form, :issue_save]
  prepend_before_filter :find_all_records, only: [:show, :edit, :update, :destroy, 
    :entries_index, :add_learners, :create_learners, :issue_form, :issue_save]
  before_filter :authenticate_user!, except: [:show, :entries_index]
  before_filter :group_admin, only: [:new, :create, :destroy]
  before_filter :badge_expert, only: [:edit, :update, :add_learners, :create_learners, :issue_form, 
    :issue_save]

  # === CONSTANTS === #

  EXPERT_WORDS = %w(expert master guide guru jedi)
  LEARNER_WORDS = %w(learner trainee student novice padawan)

  # === RESTFUL ACTIONS === #

  # GET /group-url/badge-url
  # GET /group-url/badge-url.png => Serves the badge image as a PNG file
  # GET /group-url/badge-url.json
  def show
    @entries = @badge.entries(current_user)
    @first_view_after_issued = @log && @log.has_flag?('first_view_after_issued')

    respond_to do |format|
      format.html # show.html.erb
      format.png do
        if @badge.image.nil?
          send_data BadgeMaker.build_image.to_blob, type: "image/png", disposition: "inline"
        else
          send_data @badge.image.encode('ISO-8859-1'), type: "image/png", disposition: "inline"
        end
      end
      format.json { render json: @badge, filter_user: current_user }
    end
  end

  # GET /group-url/badges/new
  # GET /group-url/badges/new.json
  def new
    @badge = Badge.new(group: @group)

    @expert_words = EXPERT_WORDS.map{ |word| word.pluralize }
    @learner_words = LEARNER_WORDS.map{ |word| word.pluralize }
    @badge.word_for_expert = EXPERT_WORDS.first # values are singularized in page
    @badge.word_for_learner = LEARNER_WORDS.first # values are singularized in page

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @badge, filter_user: current_user }
    end
  end

  # GET /group-url/badge-url/edit
  def edit
    @expert_words = EXPERT_WORDS.map{ |word| word.pluralize }
    @expert_words << @badge.word_for_expert.pluralize \
      if !@expert_words.include? @badge.word_for_expert.pluralize
    @learner_words = LEARNER_WORDS.map{ |word| word.pluralize }
    @learner_words << @badge.word_for_learner.pluralize \
      if !@badge.word_for_learner.blank? && !@learner_words.include?(@badge.word_for_learner.pluralize)
  end

  # POST /group-url/badges
  # POST /group-url/badges.json
  def create
    @badge = Badge.new(params[:badge])
    @badge.group = @group
    @badge.creator = current_user
    @badge.current_user = current_user
    @badge.current_username = current_user.username

    @expert_words = EXPERT_WORDS.map{ |word| word.pluralize }
    @expert_words << @badge.word_for_expert.pluralize \
      if !@expert_words.include? @badge.word_for_expert.pluralize
    @learner_words = LEARNER_WORDS.map{ |word| word.pluralize }
    @learner_words << @badge.word_for_learner.pluralize \
      if !@badge.word_for_learner.blank? && !@learner_words.include?(@badge.word_for_learner.pluralize)

    respond_to do |format|
      if @badge.save
        format.html { redirect_to @group, 
          notice: "The '#{@badge.name}' badge was successfully created." }
        format.json { render json: @badge, status: :created, location: @badge, filter_user: current_user }
      else
        flash[:error] = "There was an error creating the badge."
        format.html { render action: "new" }
        format.json { render json: @badge.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /group-url/badge-url
  # PUT /group-url/badge-url?modal=true >> Redirects back to group with flash error on save failure
  # PUT /group-url/badge-url.json
  def update
    @badge.current_user = current_user
    @badge.current_username = current_user.username

    @expert_words = EXPERT_WORDS.map{ |word| word.pluralize }
    @expert_words << @badge.word_for_expert.pluralize \
      if !@expert_words.include? @badge.word_for_expert.pluralize
    @learner_words = LEARNER_WORDS.map{ |word| word.pluralize }
    @learner_words << @badge.word_for_learner.pluralize \
      if !@badge.word_for_learner.blank? && !@learner_words.include?(@badge.word_for_learner.pluralize)
    
    respond_to do |format|
      if @badge.update_attributes(params[:badge])
        format.html { redirect_to [@group, @badge], notice: 'Badge was successfully updated.' }
        format.json { head :no_content }
      else
        format.html do 
          if params[:modal]
            flash[:error] = "There was a problem updating the badge, try again later.\nError Text: #{@badge.errors}"
            render action: "show"
          else
            render action: "edit"
          end
        end
        format.json { render json: @badge.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /group-url/badge-url
  # DELETE /group-url/badge-url.json
  def destroy
    @badge.destroy

    respond_to do |format|
      format.html { redirect_to @group, notice: "The badge has been deleted." } # fixme: redirect to the learning group
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
    @entries = @badge.entries(current_user, nil, @page, @page_size)

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
  def create_learners
    @notify_by_email = params[:notify_by_email] == "1"
    new_learner_count = 0
    new_learner_log = nil

    params[:usernames].each do |username|
      user = User.find(username.to_s.downcase) rescue nil
      if user && !user.learner_of?(@badge) && !user.expert_of?(@badge)
        new_learner_log = @badge.add_learner(user)
        new_learner_count += 1
        
        if @notify_by_email
          begin
            UserMailer.log_new(user, current_user, @group, @badge, new_learner_log).deliver 
          rescue Exception => e
            logger.error "+++badges_controller.create_learners: " \
            + "There was an error sending an email to #{user}. " \
            + "Exception = #{e.inspect}+++"
          end
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
      flash[:error] = "The summary can't be longer than #{Entry::MAX_SUMMARY_LENGTH} characters. " \
        + "If you need more space you can use the body text."
      render 'issue_form'
    else
      user = User.find_by(email: @email) rescue nil
      if user.nil?
        # add them to the group invited members (but be sure not to create a dupe)
        if @group.has_invited_member? @email
          found_user = @group.invited_members.detect { |u| u["email"] == @email}
          found_user[:validations] = [] unless found_user.include? :validations
          found_user[:validations] << { badge: @badge.url, summary: @summary, body: @body, user: current_user._id }
        elsif @group.has_invited_admin? @email
          found_user = @group.invited_admins.detect { |u| u["email"] == @email}
          found_user[:validations] = [] unless found_user.include? :validations
          found_user[:validations] << { badge: @badge.url, summary: @summary, body: @body, user: current_user._id }
        else
          @group.invited_members << { email: @email, invite_date: Time.now, 
            validations: [{ badge: @badge.url, summary: @summary, body: @body, user: current_user._id }] }
        end

        # send the email and then save the group (if there's no error sending the email)
        begin
          NewUserMailer.badge_issued(@email, nil, current_user, @group, @badge).deliver
          @group.save!
          redirect_to [@group, @badge], 
            notice: "A notice of badge achievement was sent to #{@email}. " \
            + "Note: The user will have to create a Badge List account to accept the badge."
        rescue Exception => e
          logger.error "+++badges_controller.issue_save: " \
            + "There was an error sending an email to #{@email}. " \
            + "Exception = #{e.inspect}+++"
          flash[:error] = "There was an error issuing the badge to the following email address: #{@email}."
          render 'issue_form'  
        end
      elsif user.expert_of? @badge
        flash[:error] = "#{user.name} is already a badge expert! You can't issue them the badge twice."
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
      else
        # create membership, log and validation
        @group.members << user
        @group.save
        log = @badge.add_learner user
        log.add_validation current_user, @summary, @body, true
        redirect_to [@group, @badge], notice: "#{user.name} has been issued the badge and " \
          + "added as a learning group member."
      end
    end
  end

private

  def find_parent_records
    @group = Group.find(params[:group_id]) || not_found
    @current_user_is_admin = current_user && current_user.admin_of?(@group)
    @current_user_is_member = current_user && current_user.member_of?(@group)
    @badge_list_admin = current_user && current_user.admin?
  end

  def find_all_records
    find_parent_records

    @badge = @group.badges.find_by(url: (params[:id] || params[:badge_id]).to_s.downcase) || not_found
    @current_user_is_expert = current_user && current_user.expert_of?(@badge)
    @current_user_is_learner = current_user && current_user.learner_of?(@badge)
    if @current_user_is_learner || @current_user_is_expert
      @log = @badge.logs.find_by(user: current_user)
    end

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

  def badge_expert
    unless @current_user_is_expert || @badge_list_admin
      flash[:error] = "You must be a badge expert to do that!"
      redirect_to [@group, @badge]
    end 
  end

end
