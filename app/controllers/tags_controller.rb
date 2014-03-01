class TagsController < ApplicationController
  include StringTools

  prepend_before_filter :find_parent_records, only: :index
  prepend_before_filter :find_all_records, except: :index
  before_filter :authenticate_user!, only: [:edit, :update, :destroy]
  before_filter :can_view_tag, only: [:show]
  before_filter :badge_expert_or_learner, only: [:edit, :update]

  # === CONSTANTS === #

  TAG_EDITABILITY_OPTIONS = [
    ['Badge experts and badge learners', 'learners'],
    ['Only badge experts', 'experts']
  ]

  # === RESTFUL ACTIONS === #

  def index
    @topics = []
    tag_names = []

    @badge.tags.each do |tag|
      tag_names << tag.name
      @topics << tag
    end

    @badge.topics.each do |topic_item|
      unless tag_names.include? topic_item[:tag_name]
        cur_tag = Tag.new
        cur_tag.name = topic_item[:tag_name]
        cur_tag.name_with_caps = topic_item[:tag_name_with_caps]
        cur_tag.display_name = topic_item[:tag_display_name]

        @topics << cur_tag
      end
    end

    @topics.sort_by! { |topic| topic.display_name || topic.name || 'z' }
  end


  # Accepts page parameters: page, page_size
  # GET /group-url/badge-url/tag-name
  # GET /group-url/badge-url/tag-name.json
  def show
    # Query for entries with this tag
    @page = params[:page] || 1
    @page_size = params[:page_size] || APP_CONFIG['page_size_normal']
    @entries = @badge.entries(current_user, @tag.name_with_caps, @page, @page_size)
    @version = (@tag.wiki_versions.blank?) ? 0 : @tag.wiki_versions.count

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @tag }
    end
  end

  # GET /group-url/badge-url/tag-name/edit
  def edit
    @tag_editability_options = TAG_EDITABILITY_OPTIONS
  end

  # PUT /group-url/badge-url/tag-name
  # PUT /group-url/badge-url/tag-name.json
  def update
    @tag.current_user = current_user
    @tag.current_username = current_user.username
    @tag_editability_options = TAG_EDITABILITY_OPTIONS

    respond_to do |format|
      if @tag_exists
        if @tag.update_attributes(params[:tag])
          format.html { redirect_to [@group, @badge, @tag], 
            notice: 'Topic page was successfully updated.' }
          format.json { head :no_content }
        else
          format.html { render action: "edit" }
          format.json { render json: @tag.errors, status: :unprocessable_entity }
        end
      else
        @tag.badge = @badge
        if @tag.save
          format.html { redirect_to [@group, @badge, @tag], 
            notice: 'Topic page was successfully created.' }
          format.json { head :no_content }
        else
          format.html { render action: "edit" }
          format.json { render json: @tag.errors, status: :unprocessable_entity }
        end
      end
    end
  end

  # DELETE /group-url/badge-url/tag-name
  # DELETE /group-url/badge-url/tag-name.json
  def destroy
    @tag.destroy

    respond_to do |format|
      format.html { redirect_to [@group, @badge], notice: 'Topic page was deleted.' }
      format.json { head :no_content }
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
    @current_user_log = current_user.logs.find_by(badge: @badge) rescue nil if current_user
  end
  
  def find_all_records
    find_parent_records

    # Try to find the tag
    @tag = @badge.tags.find_by(name: (params[:tag_id] || params[:id]).to_s.downcase) rescue nil
    @tag_exists = !@tag.nil?

    # If the tag doesn't exist yet then create one in case the user wants to edit it
    if !@tag_exists
      if params[:tag].nil?
        @tag = Tag.new
        @tag.name_with_caps = params[:tag_id] || params[:id]
        @tag.name = @tag.name_with_caps.downcase
        @tag.display_name = @badge.tag_display_name(@tag.name) || detagify_string(@tag.name_with_caps)
      else
        @tag = Tag.new(params[:tag])
      end
    end
  end

  def can_view_tag
    unless @group.public? || @current_user_is_member || @current_user_is_admin
      redirect_to [@group, @badge], error: "This is a private group."
    end
  end

  def badge_expert_or_learner
    unless @current_user_is_expert || @current_user_is_learner
      redirect_to [@group, @badge], 
        error: "You must be an expert or learner of the badge to edit topic pages."
    end
  end  

end

