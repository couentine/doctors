class BadgesController < ApplicationController
  
  before_filter :find_badge, only: [:show, :edit, :update, :destroy]
  before_filter :authenticate_user!, only: [:index, :new, :edit, :create, :update, :destroy]

  # GET /group-url/badges
  # GET /group-url/badges.json
  def index
    @badges = Badge.asc(:name).page(params[:page]).per(APP_CONFIG['page_size'])

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @badges }
    end
  end

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
    @group = Group.find(params[:group_id])
    @badge = Badge.new(group: @group)

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @badge }
    end
  end

  # GET /group-url/badge-url/edit
  def edit
    # badge is found by find_badge, so nothing to do here
  end

  # POST /group-url/badges
  # POST /group-url/badges.json
  def create
    @group = Group.find(params[:group_id])
    @badge = Badge.new(params[:badge])
    @badge.group = @group
    @badge.creator = current_user
    @badge.current_user = current_user
    @badge.current_user_name = current_user.name

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
    @badge.current_user_name = current_user.name
    
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

private

  def find_badge
    @group = Group.find(params[:group_id])
    @badge = Badge.find_by(group: @group.id, url: params[:id])
    @current_user_is_admin = current_user.admin_of?(@group)
    @current_user_is_expert = @current_user_is_admin # for now we'll use this as a proxy
    @current_user_is_learner = current_user.member_of?(@group)
  end

end
