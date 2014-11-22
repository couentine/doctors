class TagsController < ApplicationController
  include StringTools

  prepend_before_filter :find_parent_records, only: :index
  prepend_before_filter :find_all_records, except: :index
  before_filter :authenticate_user!, only: [:edit, :update, :destroy, :restore]
  before_filter :can_view_tag, except: [:index]
  before_filter :can_edit_tag, only: [:edit, :update, :restore]
  before_filter :badge_expert, only: [:destroy]

  # === RESTFUL ACTIONS === #

  def index
    @topics = []
    tag_names = []

    @badge.tags.each do |tag|
      tag_names << tag.name
      @topics << tag
    end

    @badge.topics.each do |topic_item|
      if !topic_item['tag_name'].blank? && !tag_names.include?(topic_item['tag_name'])
        cur_tag = Tag.new
        cur_tag.name = topic_item['tag_name']
        cur_tag.name_with_caps = topic_item['tag_name_with_caps']
        cur_tag.display_name = topic_item['tag_display_name']

        @topics << cur_tag
      end
    end

    @topics.sort_by! { |topic| topic.display_name || topic.name || 'z' }
  end


  # Accepts page parameters: page, page_size
  # GET /group-url/badge-url/tag-name
  # GET /group-url/badge-url/tag-name.json
  # VERSION: If a "v" parameter is included (even if blank) then a @version_list will be initialized.
  #          If the v parameter is an integer then that version of the wiki page will be loaded.
  def show
    # Query for entries with this tag
    @page = params[:page] || 1
    @page_size = params[:page_size] || APP_CONFIG['page_size_normal']
    @entries = @badge.entries(current_user, @tag.name_with_caps, @page, @page_size)
    @version_list = []
    
    # Now initialize version info
    @show_version_list = (@tag_exists && params.include?(:v) && !@tag.wiki_versions.blank?)
    if @show_version_list
      @version_list = @tag.wiki_versions
      @current_version = params[:v].to_i
      if (@current_version < 1) || (@current_version >= @tag.wiki_versions.count)
        @current_version = @tag.wiki_versions.count
        @current_version_info = @version_list.last
      else
        @current_version_info = @version_list[@current_version - 1]

        # Temporarily "restore" this version in memory (Note: We are NOT saving this to the DB.)
        @tag.wiki = @current_version_info['wiki']
        linkified_result = linkify_text(@tag.wiki, @group, @badge)
        @tag.wiki_sections = linkified_result[:text].split(SECTION_DIVIDER_REGEX)
        @tag.tags = linkified_result[:tags]
        @tag.tags_with_caps = linkified_result[:tags_with_caps]
      end
    elsif @tag_exists && !@tag.wiki_versions.blank?
      @current_version = @tag.wiki_versions.count
      @current_version_info = @tag.wiki_versions.last
    else
      @current_version = 0
      @current_version_info = nil
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @tag, filter_user: current_user }
    end
  end

  # GET /group-url/badge-url/tag-name/edit
  def edit
    # Nothing to do here.
  end

  # PUT /group-url/badge-url/tag-name
  # PUT /group-url/badge-url/tag-name.json
  def update
    @tag.current_user = current_user
    @tag.current_username = current_user.username

    respond_to do |format|
      if @tag_exists
        if @tag.update_attributes(params[:tag])
          format.html do
            flash[:notice] = 'Requirement page was successfully updated.'
            redirect_to [@group, @badge, @tag]
          end
          format.json { head :no_content }
        else
          format.html { render action: "edit" }
          format.json { render json: @tag.errors, status: :unprocessable_entity }
        end
      else
        @tag.badge = @badge
        if @tag.save
          format.html do
            flash[:notice] = 'Requirement page was successfully created.'
            redirect_to [@group, @badge, @tag]
          end
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
      format.html do
        flash[:notice] = 'Requirement page was deleted.'
        redirect_to [@group, @badge]
      end
      format.json { head :no_content }
    end
  end

# === NON-RESTFUL ACTIONS === #

  # POST /group-url/badge-url/tag-name/restore?v=1
  # Restores a particular version of the topic page
  def restore
    version = params[:v].to_i # Note: nil.to_i = 0

    if (version < 1) || (version >= @tag.wiki_versions.count)
      flash[:error] = 'You must specify a valid version of the topic page to restore.'
      redirect_to group_badge_tag_path(@group, @badge, @tag, v: '')
    else
      @tag.current_user = current_user
      @tag.current_username = current_user.username
      @tag.wiki = @tag.wiki_versions[version - 1]['wiki']

      if @tag.save
        flash[:notice] = "You have restored version #{version} of the topic page."
        redirect_to [@group, @badge, @tag]
      else
        flash[:error] = "There was an error trying to restore version #{version} of the topic page. " \
         + "Please try again later."
        redirect_to group_badge_tag_path(@group, @badge, @tag, v: version)
      end
    end
  end

private

  def find_parent_records
    @group = Group.find(params[:group_id].to_s.downcase) || not_found
    @group.log_active_user current_user # log monthly active user if applicable
    @badge = @group.badges.find_by(url: params[:badge_id].to_s.downcase) || not_found
    @current_user_is_admin = current_user && current_user.admin_of?(@group)
    @current_user_is_member = current_user && current_user.member_of?(@group)
    @current_user_is_expert = current_user && current_user.expert_of?(@badge)
    @current_user_is_learner = current_user && current_user.learner_of?(@badge)
    @current_user_log = current_user.logs.find_by(badge: @badge) rescue nil if current_user
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

    @tag_editability_options = [
      ["#{@Experts} and #{@Learners}", 'learners'],
      ["Only #{@Experts}", 'experts']
    ]
  end
  
  def find_all_records
    find_parent_records

    # Try to find the tag
    @tag = @badge.tags.find_by(name: (params[:tag_id] || params[:id]).to_s.downcase) rescue nil
    @tag_exists = !@tag.nil?

    # If the tag doesn't exist yet then create one in case the user wants to edit it
    if @tag_exists
      @can_edit_tag = @current_user_is_expert \
        || (@current_user_is_learner && (@tag.editability == 'learners'))
    else
      @can_edit_tag = @current_user_is_expert || @current_user_is_learner

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
    unless @group.public? || @current_user_is_member || @current_user_is_admin || @badge_list_admin
      flash[:error] = "This is a private group."
      redirect_to [@group, @badge]
    end
  end

  def can_edit_tag
    if !@current_user_is_expert && !@badge_list_admin \
      && !(@current_user_is_learner && (@tag.editability == 'learners'))

      flash[:error] = "This topic page is only editable by badge experts."
      redirect_to [@group, @badge, @tag]
    end
  end

  def badge_expert
    unless @current_user_is_expert || @badge_list_admin
      flash[:error] = "Only badge experts can delete topic pages."
      redirect_to [@group, @badge, @tag]
    end
  end

end

