class BadgesController < ApplicationController
  
  before_filter :find_badge, only: [:show, :edit, :update, :destroy]
  before_filter :authenticate_user!, only: [:index, :new, :edit, :create, :update, :destroy]

  # GET /badges
  # GET /badges.json
  def index
    @badges = Badge.asc(:name).page(params[:page]).per(APP_CONFIG['page_size'])

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @badges }
    end
  end

  # GET /badges/1
  # GET /badges/1.json
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @badge }
    end
  end

  # GET /badges/new
  # GET /badges/new.json
  def new
    @group = Group.find(params[:group_id])
    @badge = Badge.new(group: @group)

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @badge }
    end
  end

  # GET /badges/1/edit
  def edit
    # badge is found by find_badge, so nothing to do here
  end

  # POST /badges
  # POST /badges.json
  def create
    respond_to do |format|
      if @badge.save
        format.html { redirect_to @badge, notice: 'Badge was successfully created.' }
        format.json { render json: @badge, status: :created, location: @badge }
      else
        format.html { render action: "new" }
        format.json { render json: @badge.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /badges/1
  # PUT /badges/1.json
  def update
    respond_to do |format|
      if @badge.update_attributes(params[:badge])
        format.html { redirect_to @badge, notice: 'Badge was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @badge.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /badges/1
  # DELETE /badges/1.json
  def destroy
    @badge.destroy

    respond_to do |format|
      format.html { redirect_to root_url } # fixme: redirect to the learning group
      format.json { head :no_content }
    end
  end

private

  def find_badge
    @group = Group.find(params[:group_id])
    @badge = Badge.find_by(group: @group.id, url: params[:id])
  end

end
