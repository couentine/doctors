class TagsController < ApplicationController
  include StringTools

  prepend_before_action :find_parent_records, only: :index
  prepend_before_action :find_all_records, except: :index
  before_action :authenticate_user!, only: [:edit, :update, :destroy, :restore]
  before_action :can_edit_tag, only: [:edit, :update, :restore]
  before_action :badge_expert, only: [:destroy]
  before_action :set_editing_parameters, only: [:edit, :update]

  # === RESTFUL ACTIONS === #

  def index
    @topics = @badge.wikis
  end


  # Accepts page parameters: page, page_size
  # GET /group-url/badge-url/tag-name
  # GET /group-url/badge-url/tag-name.json
  # VERSION: If a "v" parameter is included (even if blank) then a @version_list will be initialized.
  #          If the v parameter is an integer then that version of the wiki page will be loaded.
  def show
    # Query for entries with this tag
    @page = params[:page] || 1
    @page_size = params[:page_size] || APP_CONFIG['page_size_small']
    @version_list = []
    if @current_user_log
      @entries = @tag.entries.where(:log.ne => @current_user_log).desc(:updated_at)\
        .page(@page).per(@page_size)
      @current_user_entries = @current_user_log.entries.where(tag: @tag).desc(:updated_at)
    else
      @entries = @tag.entries.desc(:updated_at).page(@page).per(@page_size)
      @current_user_entries = []
    end
    
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

    # Now we build maps for partials (it's sort of a process but saves 2 queries per entry)

    @log_map, @user_map = {}, {}
    log_reverse_map, user_reverse_map = {}, {}
    log_ids, user_ids = [], []
    
    # Start by running through entries and gathering log ids while mapping back to the entries
    @entries.each do |entry|
      log_ids << entry.log_id
      if log_reverse_map.has_key? entry.log_id
        log_reverse_map[entry.log_id] << entry.id
      else
        log_reverse_map[entry.log_id] = [entry.id]
      end
    end

    # Now run through and build the log map while setting up the user reverse map and id list
    Log.where(:id.in => log_ids).each do |log|
      log_reverse_map[log.id].each{ |entry_id| @log_map[entry_id] = log }

      # there can be only 1 log per user per badge so we can just copy the log's reverse map values
      user_reverse_map[log.user_id] = log_reverse_map[log.id] 
      user_ids << log.user_id
    end
    
    # Finally we query users and build the user map
    User.where(:id.in => user_ids).each do |user|
      user_reverse_map[user.id].each{ |entry_id| @user_map[entry_id] = user }
    end

    # Done!

    respond_to do |format|
      format.html do 
        if (@tag.name == 'topics') && !@tag_exists
          @topics = @badge.wikis
          render :index
        end
        # else: show.html.erb
      end
      format.js # show.js.erb
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
        if @tag.update_attributes(tag_params)
          format.html do
            flash[:notice] = "#{@tag.type.capitalize} page was successfully updated."
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
          # First update analytics if this is a wiki page
          if @tag.type == 'wiki'
            IntercomEventWorker.perform_async({
              'event_name' => 'wiki-create',
              'email' => current_user.email,
              'user_id' => current_user.id.to_s,
              'created_at' => Time.now.to_i,
              'metadata' => {
                'group_id' => @group.id.to_s,
                'group_name' => @group.name,
                'badge_id' => @badge.id.to_s,
                'badge_name' => @badge.name,
                'badge_url' => @badge.badge_url,
                'tag_name' => @tag.name_with_caps,
                'tag_url' => "#{@badge.badge_url}/#{@tag.name_with_caps}".first(255)
              }
            })
          end

          # Then respond to user
          format.html do
            flash[:notice] = "#{@tag.type.capitalize} page was successfully created."
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
    # We can only delete this tag if it has no child entries (otherwise they will be orphaned)
    deletion_restricted = !@tag.entries.blank?
    @tag.destroy unless deletion_restricted

    respond_to do |format|
      format.html do
        if deletion_restricted
          flash[:error] = 'You cannot delete this requirement page because evidence has been ' \
            + 'posted to it. Try removing the requirement from the badge requirements list ' \
            + 'instead. That will leave the requirement page in existence but remove it from view.'
          redirect_to [@group, @badge, @tag]
        else
          flash[:notice] = 'Requirement page was deleted.'
          redirect_to [@group, @badge]
        end
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
    @badge = @group.badges.find_by(url: params[:badge_id].to_s.downcase) || not_found
    @current_user_is_admin = current_user && current_user.admin_of?(@group)
    @current_user_is_member = current_user && current_user.member_of?(@group)
    @current_user_is_expert = current_user && current_user.expert_of?(@badge)
    @current_user_is_learner = current_user && current_user.learner_of?(@badge)
    @current_user_log = current_user.logs.find_by(badge: @badge) rescue nil if current_user
    @badge_list_admin = current_user && current_user.admin?

    # Set current group (for analytics) only if user is logged in and an admin
    @current_user_group = @group if @current_user_is_admin

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
  
  def find_all_records
    find_parent_records

    # Try to find the tag
    @tag = @badge.tags.find_by(name: (params[:tag_id] || params[:id]).to_s.downcase) rescue nil
    @tag_exists = !@tag.nil?

    # If the tag doesn't exist yet then create one in case the user wants to edit it
    if @tag_exists
      @can_edit_tag = @current_user_is_admin || @badge_list_admin \
        || (@current_user_is_expert && (@tag.editability == 'experts')) \
        || ((@current_user_is_learner || @current_user_is_expert) \
          && (@tag.editability == 'learners'))
    else
      @can_edit_tag = @current_user_is_admin || @badge_list_admin \
        || (@group.has?(:community) && (@current_user_is_expert || @current_user_is_learner))

      if params[:tag].nil?
        @tag = Tag.new
        @tag.name_with_caps = params[:tag_id] || params[:id]
        @tag.name = @tag.name_with_caps.downcase
        @tag.display_name = detagify_string(@tag.name_with_caps)
      else
        @tag = Tag.new(tag_params)
      end
    end

    # Figure out if the current user can see the entries in this tag
    # NOTE: If this group is private then the @can_see_badge param handles blocking non-members
    #       So we really only need to worry about the "secret" level of privacy. 
    #       (But it's not that hard to be super accurate so we will be.)
    @current_user_can_see_entries = (@tag.type == 'requirement') && (@badge_list_admin \
        || (@tag.privacy == 'public') \
        || ((@tag.privacy == 'private') && (@current_user_is_member || @current_user_is_admin)) \
        || ((@tag.privacy == 'secret') && (@current_user_is_admin \
          || ((@badge.awardability == 'experts') && @current_user_is_expert))))
  end

  def can_edit_tag
    unless @can_edit_tag
      flash[:error] = "You do not have permission to edit this requirement page."
      redirect_to [@group, @badge, @tag]
    end
  end

  def badge_expert
    unless @current_user_is_expert || @badge_list_admin
      flash[:error] = "Only badge experts can delete requirement pages."
      redirect_to [@group, @badge, @tag]
    end
  end

  def set_editing_parameters
    # Build format options
    @tag_format_options = [
      ['Any Format', 'any'],
      ['Free Text Response', 'text'],
      ['Web Link', 'link'],
      ['Image Upload', 'image']
    ] + ((@group.has?(:file_uploads)) ? [['File Upload', 'file']] : []) \
    + [
      ['Twitter Link', 'tweet'],
      ['Code Snippet', 'code']
    ]

    # Build editability options
    @tag_editability_options = [
      ["#{@Experts}, #{@Learners} and Admins", 'learners'],
      ["Only #{@Experts} & Admins", 'experts']
    ]
    if @current_user_is_admin || @badge_list_admin
      @tag_editability_options << ['Only Group Admins', 'admins'] 
    end
    
    # Build privacy options
    @tag_privacy_options = []
    Tag.privacy_values(@group.has?(:privacy)).each do |privacy_string|
      @tag_privacy_options << [
        ("<strong>#{privacy_string.capitalize}</strong>" \
        + " - #{Tag.privacy_text(@group.has?(:privacy), privacy_string).capitalize}").html_safe,
        privacy_string
      ]
    end
  end

  def tag_params
    params.require(:tag).permit(:display_name, :type, :format, :sort_order, :summary, :wiki, 
      :editability, :privacy)
  end

end

