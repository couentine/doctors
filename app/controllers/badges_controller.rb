class BadgesController < ApplicationController
  
  prepend_before_filter :find_parent_records, except: [:show, :edit, :update, :destroy, 
    :entries_index, :add_learners, :create_learners]
  prepend_before_filter :find_all_records, only: [:show, :edit, :update, :destroy, 
    :entries_index, :add_learners, :create_learners]
  before_filter :authenticate_user!, except: [:show, :entries_index]
  before_filter :group_admin, only: [:new, :create, :destroy]
  before_filter :badge_expert, only: [:edit, :update, :add_learners, :create_learners]

  # === RESTFUL ACTIONS === #

  # GET /group-url/badge-url
  # GET /group-url/badge-url.png => Serves the badge image as a PNG file
  # GET /group-url/badge-url.json
  def show
    @entries = @badge.entries(current_user)

    respond_to do |format|
      format.html # show.html.erb
      format.png do
        if @badge.image.nil?
          send_data BadgeMaker.build_image.to_blob, type: "image/png", disposition: "inline"
        else
          send_data @badge.image.encode('ISO-8859-1'), type: "image/png", disposition: "inline"
        end
      end
      format.json { render json: @badge }
    end
  end

  # GET /group-url/badges/new
  # GET /group-url/badges/new.json
  def new
    @badge = Badge.new(group: @group)

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @badge }
    end
  end

  # GET /group-url/badge-url/edit
  def edit
    # badge is found by find_records, so nothing to do here
  end

  # POST /group-url/badges
  # POST /group-url/badges.json
  def create
    @badge = Badge.new(params[:badge])
    @badge.group = @group
    @badge.creator = current_user
    @badge.current_user = current_user
    @badge.current_username = current_user.username

    respond_to do |format|
      if @badge.save
        format.html { redirect_to group_badge_path(@group, @badge), notice: 'Badge was successfully created.' }
        format.json { render json: @badge, status: :created, location: @badge }
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
      format.json { render json: @badge }
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
          UserMailer.log_new(user, current_user, @group, @badge, new_learner_log).deliver 
        end
      end
    end

    respond_to do |format|
      format.html { redirect_to group_badge_path(@group, @badge)+'#learners', 
        notice: "#{new_learner_count} learners were added to the badge." } 
      format.json { head :no_content }
    end
  end

private

  def find_parent_records
    @group = Group.find(params[:group_id]) || not_found
    @current_user_is_admin = current_user && current_user.admin_of?(@group)
    @current_user_is_member = current_user && current_user.member_of?(@group)
  end

  def find_all_records
    find_parent_records

    @badge = @group.badges.find_by(url: (params[:id] || params[:badge_id]).to_s.downcase) || not_found
    @current_user_is_expert = current_user && current_user.expert_of?(@badge)
    @current_user_is_learner = current_user && current_user.learner_of?(@badge)
    if @current_user_is_learner || @current_user_is_expert
      @log = @badge.logs.find_by(user: current_user)
    end
  end

  def group_admin
    unless @current_user_is_admin
      flash[:error] = "You must be a group admin to do that!"
      redirect_to @group
    end 
  end

  def badge_expert
    unless @current_user_is_expert
      flash[:error] = "You must be a badge expert to do that!"
      redirect_to [@group, @badge]
    end 
  end

end
