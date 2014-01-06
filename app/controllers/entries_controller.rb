class EntriesController < ApplicationController
  include UsersHelper
  
  prepend_before_filter :find_parent_records, except: [:show, :edit, :update, :destroy]
  prepend_before_filter :find_all_records, only: [:show, :edit, :update, :destroy]
  before_filter :authenticate_user!, only: [:edit, :new, :create, :update, :destroy]
  before_filter :entry_creator, only: [:edit, :update]
  before_filter :log_owner_or_entry_creator, only: [:destroy]
  before_filter :badge_expert_or_log_owner, only: [:new, :create]

  # === RESTFUL ACTIONS === #

  # GET /group-url/badge-url/u/username/1
  # GET /group-url/badge-url/u/username/1.json
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @entry }
    end
  end

  # This returns a form for a POST type entry by default.
  # To specify a validation, include "type" parameter set to "validation"
  # GET /group-url/badge-url/u/username/entries/new => NEW POST
  # GET /group-url/badge-url/u/username/entries/new?type=validation => NEW VALIDATION
  # GET /group-url/badge-url/u/username/entries/new.json
  def new
    @entry = Entry.new
    privacy_count = cookies[:log_privacy_count]
    @entry.private = privacy_count && (privacy_count > 2) # They have to pick private twice in a row

    respond_to do |format|
      format.html do
        if params[:type] == 'validation'
          render :new
        else
          render :new_validation
      end
      format.json { render json: @entry }
    end
  end

  # GET /group-url/badge-url/u/username/1/edit
  def edit
    if @entry.type == 'validation'
      render :edit_validation
    else
      render :edit
    end
  end

  # This creates a new POST type entry by default.
  # To specify a validation, include "type" parameter set to "validation"
  # POST /group-url/badge-url/u/username/entries
  # POST /group-url/badge-url/u/username/entries.json
  def create
    @entry = Entry.new(params[:entry])
    @entry.log = @log
    @entry.creator = current_user
    @entry.type = 'post'
    @entry.current_user = current_user
    @entry.current_username = current_user.username

    if params[:type] == 'validation'
      @entry.type = 'validation'
      @entry.private = false
    else # update the privacy count cookie (this controls whether private is default)
      log_privacy_count = cookies[:log_privacy_count] || 0
      delta = (@entry.private) ? 1 : -1
      # don't let the count go below zero or above 4
      log_privacy_count = [[0, log_privacy_count+delta].max, 4].min
      cookies.permanent[:log_privacy_count] = log_privacy_count
    end

    respond_to do |format|
      if (@entry.type == 'validation') && !@current_user_is_expert
        format.html { render action: "new", 
          error: "Only badge experts can validate a learning log." }
        format.json { render json: @entry.errors, status: :unprocessable_entity }
      elsif @entry.save
        format.html do
          if @entry.type == 'validation'
            redirect_to @entry, notice: 'Your learning log entry was successfully created.'
          else
            redirect_to @entry, notice: 'Your learning log validation was successfully created.'
          end
        end
        format.json { render json: @entry, status: :created, location: @entry }
      else
        format.html { render action: "new" }
        format.json { render json: @entry.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /group-url/badge-url/u/username/1
  # PUT /group-url/badge-url/u/username/1.json
  def update
    @entry.current_user = current_user
    @entry.current_username = current_user.username

    respond_to do |format|
      if @entry.update_attributes(params[:entry])
        format.html do
          if @entry.type == 'validation'
            redirect_to @entry, notice: 'Validation was successfully updated.'
          else
            redirect_to @entry, notice: 'Entry was successfully updated.'
          end
        end
        format.json { head :no_content }
      else
        format.html do
          if @entry.type == 'validation'
            render :edit_validation
          else
            render :edit
          end
        end
        format.json { render json: @entry.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /group-url/badge-url/u/username/1
  # DELETE /group-url/badge-url/u/username/1.json
  def destroy
    @entry.destroy

    respond_to do |format|
      format.html { redirect_to entries_url }
      format.json { head :no_content }
    end
  end

private

  def find_parent_records
    @group = Group.find(params[:group_id])
    @badge = @group.badges.find_by(url: params[:badge_id].to_s.downcase)
    @user = User.find(params[:log_id].to_s.downcase) # find user by username
    @log = @user.logs.find_by(badge: @badge)
    @current_user_is_admin = current_user && current_user.admin_of?(@group)
    @current_user_is_member = current_user && current_user.member_of?(@group)
    @current_user_is_expert = current_user && current_user.expert_of?(@badge)
    @current_user_is_learner = current_user && current_user.learner_of?(@badge)
    @current_user_is_log_owner = current_user && (current_user == @log.user)
  end

  def find_all_records
    find_parent_records

    @entry = @log.entries.find_by(entry_number: (params[:entry_id] || params[:id]))
    @current_user_is_entry_creator = current_user && (current_user == @entry.creator)
  end

  def entry_creator
    unless @current_user_is_entry_creator
      flash[:error] = "That action is restricted to the entry creator."
      redirect_to [@group, @badge, @log, @entry]
    end
  end

  def log_owner_or_entry_creator
    unless @current_user_is_log_owner || @current_user_is_entry_creator
      flash[:error] = "That action is restricted to the log owner or the entry creator."
      redirect_to [@group, @badge, @log, @entry]
    end
  end

  def badge_expert_or_log_owner
    unless @current_user_is_expert || @current_user_is_log_owner
      flash[:error] = "That action is restricted to badge experts and the log owner."
      redirect_to [@group, @badge, @log]
    end
  end

end