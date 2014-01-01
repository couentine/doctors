class BadgesController < ApplicationController
  
  before_filter :find_related_records
  before_filter :find_badge, only: [:show, :edit, :update, :destroy, :add_learners]
  before_filter :authenticate_user!, only: [:new, :edit, :create, :update, :destroy]
  before_filter :group_admin, only: [:new, :create, :destroy]
  before_filter :badge_expert, only: [:edit, :update, :add_learners]

  # === RESTFUL ACTIONS === #

  # GET /group-url/badge-url
  # GET /group-url/badge-url.json
  def show
    respond_to do |format|
      format.html # show.html.erb
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
        format.html { render action: "new", error: 'Oops! Looks like something was missing.' }
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
            render action: "show", 
            error: "There was a problem updating the badge, try again later.\nError Text: #{@badge.errors}"
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

  # GET /group-url/badge-url/learners/add
  # GET /group-url/badge-url/learners/add.json
  # :usernames => array_of_usernames_to_add[]
  def add_learners
    new_learner_count = 0

    params[:usernames].each do |username|
      user = User.find(username.to_s.downcase) rescue nil
      if user
        log = @badge.add_learner(user)
        new_learner_count += 1
      end
    end

    respond_to do |format|
      format.html { redirect_to [@group, @badge], 
        notice: "#{new_learner_count} learners were added to the badge." } 
      format.json { head :no_content }
    end
  end

private

  def find_related_records
    @group = Group.find(params[:group_id])
    @current_user_is_admin = current_user.admin_of?(@group)
    @current_user_is_member = current_user.member_of?(@group)
  end

  def find_badge
    @badge = @group.badges.find_by(url: params[:id].to_s.downcase)
    @current_user_is_expert = current_user.expert_of?(@badge)
    @current_user_is_learner = current_user.learner_of?(@badge)

    if @current_user_is_learner || @current_user_is_expert
      @log = @badge.logs.find { |log| log.user == current_user }
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
      redirect_to @badge
    end 
  end

end
