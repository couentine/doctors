class EntriesController < ApplicationController
  include UsersHelper
  
  prepend_before_filter :find_parent_records, except: [:show, :edit, :update, :destroy]
  prepend_before_filter :find_all_records, only: [:show, :edit, :update, :destroy]
  before_filter :authenticate_user!, only: [:edit, :new, :create, :update, :destroy]
  before_filter :visible_to_current_user, only: [:show]
  before_filter :entry_creator, only: [:edit, :update]
  before_filter :log_owner_or_entry_creator, only: [:destroy]
  before_filter :badge_expert_or_log_owner, only: [:new, :create]

  # === RESTFUL ACTIONS === #

  # GET /group-url/badge-url/u/username/1
  # GET /group-url/badge-url/u/username/1.json
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @entry, filter_user: current_user }
    end
  end

  # This returns a form for a POST type entry by default.
  # To specify a validation, include "type" parameter set to "validation"
  # NOTE: Will redirect to EDIT for validations that already exist
  # GET /group-url/badge-url/u/username/entries/new => NEW POST
  # GET /group-url/badge-url/u/username/entries/new?type=validation => NEW VALIDATION
  # GET /group-url/badge-url/u/username/entries/new.json
  # Accepts "tag" parameter
  def new
    @type = params[:type] || 'post'
    summary = (params[:tag].nil?) ? '' : " ##{params[:tag]}"

    if @type == 'validation'
      @entry = current_user.created_entries.find_by(log: @log, type: 'validation') rescue nil
      @validation_already_exists = !@entry.nil?
      if @validation_already_exists
        render :edit
      else
        @entry = Entry.new(summary: summary)
        @entry.private = false
        @entry.type = 'validation'
        render :new
      end
    else
      @entry = Entry.new(summary: summary, parent_tag: params[:tag])
      @entry.type = 'post'
      privacy_count = cookies[:log_privacy_count]
      @entry.private = privacy_count && (privacy_count.to_i > 2) # They have to pick private twice in a row
      @entry.private = false if @entry.private.nil?
      render :new
    end
  end

  # GET /group-url/badge-url/u/username/1/edit
  def edit
    # nothing specific to do here
  end

  # POST /group-url/badge-url/u/username/entries
  # POST /group-url/badge-url/u/username/entries.json
  def create
    @type = params[:entry][:type] || 'post'

    # First create the entry
    if @type == 'validation'
      # First determine if the validation already exists
      existing_entry = current_user.created_entries.find_by(log: @log, type: 'validation') rescue nil
      @validation_already_exists = !existing_entry.nil? # only used to set the flash message
      logger.debug "+++create: params[:entry][:log_validated] = #{params[:entry][:log_validated]}+++"
      @log_validated = (params[:entry][:log_validated] == 'true')

      # Now add the validation using the standard field (thus preventing duplicates)
      @entry = @log.add_validation current_user, params[:entry][:summary], params[:entry][:body],
        @log_validated
    else
      @entry = @log.add_post current_user, params[:entry][:summary], params[:entry][:body],
        params[:entry][:private], params[:entry][:parent_tag]
      
      # update the privacy count cookie (this controls whether private is default)
      log_privacy_count = cookies[:log_privacy_count] || 0
      delta = (@entry.private) ? 1 : -1
      # don't let the count go below zero or above 4
      # FIXME: log_privacy_count = [[0, log_privacy_count+delta].max, 4].min.to_i
      # cookies.permanent[:log_privacy_count] = log_privacy_count.to_s
    end

    
    # Now do the redirect
    if @entry.errors.count > 0
      if @entry.new_record?
        flash[:error] = "There was an error creating your #{@type}."
        render :new
      else
        flash[:error] = "There was an error updating your #{@type}."
        render :edit
      end
    else
      if (@type == 'validation') && @validation_already_exists
        notice = "Your validation was updated."
      else
        notice = "Your #{@type} was created."
      end

      redirect_to [@group, @badge, @log, @entry], notice: notice
    end
  end

  # PUT /group-url/badge-url/u/username/1
  # PUT /group-url/badge-url/u/username/1.json
  def update
    @entry.current_user = current_user
    @entry.current_username = current_user.username

    respond_to do |format|
      if @entry.type == 'validation'
        @log.add_validation current_user, params[:entry][:summary], params[:entry][:body], 
          (params[:entry][:log_validated] == "true")

        format.html do
          redirect_to [@group, @badge, @log, @entry], notice: 'Validation was successfully updated.'
        end
        format.json { head :no_content }
      elsif @entry.update_attributes(params[:entry])
        format.html do
          redirect_to [@group, @badge, @log, @entry], notice: 'Post was successfully updated.'
        end
        format.json { head :no_content }
      else
        format.html do
          if @entry.type == 'validation'
            render :edit
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
      format.html { redirect_to [@group, @badge, @log] }
      format.json { head :no_content }
    end
  end

private

  def find_parent_records
    @group = Group.find(params[:group_id].to_s.downcase) || not_found
    @group.log_active_user current_user # log monthly active user if applicable
    @badge = @group.badges.find_by(url: params[:badge_id].to_s.downcase) || not_found
    @user = User.find(params[:log_id].to_s.downcase) || not_found # find user by username
    @log = @user.logs.find_by(badge: @badge) || not_found
    @current_user_is_admin = current_user && current_user.admin_of?(@group)
    @current_user_is_member = current_user && current_user.member_of?(@group)
    @current_user_is_expert = current_user && current_user.expert_of?(@badge)
    @current_user_is_learner = current_user && current_user.learner_of?(@badge)
    @current_user_is_log_owner = current_user && (current_user == @log.user)
    @badge_list_admin = current_user && current_user.admin?

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

    @entry = @log.entries.find_by(entry_number: (params[:entry_id] || params[:id])) || not_found
    @current_user_is_entry_creator = current_user && (current_user.id == @entry.creator_id)
    @visible_to_current_user = @entry.visible_to?(current_user)

    if current_user
      @current_user_log = current_user.logs.find_by(badge: @badge) rescue nil 
    end
  end

  def visible_to_current_user
    unless @visible_to_current_user
      flash[:error] = "Oops! it looks like you don't have access to this learning log entry."
      redirect_to [@group, @badge, @log]
    end
  end

  def entry_creator
    unless @current_user_is_entry_creator || @badge_list_admin
      flash[:error] = "That action is restricted to the entry creator."
      redirect_to [@group, @badge, @log, @entry]
    end
  end

  def log_owner_or_entry_creator
    unless @current_user_is_log_owner || @current_user_is_entry_creator || @badge_list_admin
      flash[:error] = "That action is restricted to the log owner or the entry creator."
      redirect_to [@group, @badge, @log, @entry]
    end
  end

  def badge_expert_or_log_owner
    unless @current_user_is_expert || @current_user_is_log_owner || @badge_list_admin
      flash[:error] = "That action is restricted to badge experts and the log owner."
      redirect_to [@group, @badge, @log]
    end
  end

end