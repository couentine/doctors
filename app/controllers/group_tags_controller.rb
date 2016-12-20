class GroupTagsController < ApplicationController
  
  prepend_before_action :find_parent_records, except: [:show, :update, :destroy, :add_users,
    :remove_users]
  prepend_before_action :find_all_records, only: [:show, :update, :destroy, :add_users,
    :remove_users]
  before_action :authenticate_user!, except: [:index, :show]
  before_action :group_admin, only: [:destroy]
  before_action :can_view, only: [:index, :show]
  before_action :can_create, only: [:create]

  # === CONSTANTS === #

  PERMITTED_PARAMS = [:name_with_caps, :summary]

  # === RESTFUL ACTIONS === #

  # HTML version returns the first page of results, JSON version is used to query future pages.
  # GET /group-url/tags
  # GET /group-url/tags.json?page=2
  def index
    # Get pagination variables
    @page_size = params['page_size'] || APP_CONFIG['page_size_large']
    @page_size = [@page_size, APP_CONFIG['page_size_large']].min # cap it at largest
    
    respond_to do |format|
      format.html do
        @group_tags_hash = GroupTag.array_json(
          @group.tags.order_by('user_magnitude desc, name asc').page(1).per(@page_size),
            :list_item)
      end
      format.json do
        @page = params['page'] || 1
        @next_page = nil

        group_tag_criteria = @group.tags.order_by('user_magnitude desc, name asc')\
          .page(@page).per(@page_size)
        @group_tags_hash = GroupTag.array_json(group_tag_criteria, :list_item)
        @next_page = @page + 1 if group_tag_criteria.count > (@page_size * @page)

        render json: { page: @page, page_size: @page_size, group_tags: @group_tags_hash, 
          next_page: @next_page, success: true }
      end
    end
  end

  # The HTML version only sets up the page size variable (used for users query), 
  # All of the querying for related users is done in json calls to group_tag_users_controller.
  # GET /group-url/tags/tag-name
  # GET /group-url/tags/tag-name.json
  def show
    @page_size = params['page_size'] || APP_CONFIG['page_size_normal']
    @page_size = [@page_size, APP_CONFIG['page_size_large']].min # cap it at largest

    respond_to do |format|
      format.html do
        # render show.html.erb
      end
      format.json do
        render json: { success: true, group_tag: @group_tag.json(:list_item) }
      end
    end
  end

  # Creates a new tag and redirects to it. If it already exists it just redirects to it.
  # If there is a problem it redirects back to the group with a flash error message.
  # POST /group-url/tags?name_with_caps=Awesome-Tag&summary=text
  def create
    # Create using the AuditHistory method
    @group_tag = GroupTag.new_with_audit(group_tag_params, current_user.id)
    if @group_tag.save
      redirect_to [@group, @group_tag], notice: 'Group tag was successfully created.'
    else
      redirect_to @group, 
        error: "There was a problem creating a tag called #{@group.name_with_caps}. " \
          + 'Try creating a tag with a different name.'
    end
  end

  # JSON only function. Returns hash w/ keys: success, errors, group_tag
  # The 'errors' key is set to the raw error hash from the object which contains field-based errors.
  # PUT /group-url/tags/tag-name.json
  def update
    respond_to do |format|
      format.json do
        # Update using the AuditHistory method
        if @group_tag.update_attributes_with_audit(group_tag_params, current_user.id)
          render json: { success: true, errors: nil, group_tag: @group_tag.json(:list_item) }
        else
          render json: { success: false, errors: @group_tag.errors, 
            group_tag: @group_tag.json(:list_item) }
        end
      end
    end
  end

  # DELETE /group-url/tags/tag-name
  def destroy
    if @group_tag.destroy
      redirect_to @group, notice: "The #{@group_tag.name_with_caps} tag was successfully deleted."
    else
      redirect_to [@group, @group_tag], 
        error: "There was a problem deleting the #{@group.name_with_caps} tag."
    end
  end

private

  def find_parent_records
    @group = Group.find(params[:group_id]) || not_found
    @current_user_is_owner = current_user && @group.owner_id && (current_user.id == @group.owner_id)
    @current_user_is_admin = current_user && current_user.admin_of?(@group)
    @current_user_is_member = current_user && current_user.member_of?(@group)
    @badge_list_admin = current_user && current_user.admin?
    
    @can_assign_group_tags = @current_user_is_admin || @badge_list_admin \
      || (@current_user_is_member && (@group.tag_assignability == 'members'))
    @can_create_group_tags = @current_user_is_admin || @badge_list_admin \
      || (@current_user_is_member && (@group.tag_creatability == 'members'))
    @can_view_group_tags = (@group.tag_visibility == 'public') \
      || @current_user_is_admin || @badge_list_admin \
      || (@current_user_is_member && (@group.tag_visibility == 'members'))
    # This one is hard-coded for now...
    @can_edit_group_tags = @current_user_is_admin || @badge_list_admin

    # Set current group (for analytics) only if user is logged in and an admin
    @current_user_group = @group if @current_user_is_admin
  end

  def find_all_records
    find_parent_records

    @group_tag = @group.tags.find_by(name: (params[:id] || params[:group_tag_id]).to_s.downcase) \
      || not_found
  end

  def group_admin
    unless @current_user_is_admin || @badge_list_admin
      flash[:error] = 'You must be a group admin to do that!'
      redirect_to @group
    end 
  end

  def can_view
    unless @can_edit_group_tags
      respond_to do |format|
        format.json do
          render json: { success: false, error_message: 'You do not have permission to view ' \
            + 'tags for this group.' }
        end
        respond_to do |html|
          flash[:error] = 'You do not have permission to view tags for this group.'
          redirect_to @group
        end
      end
    end 
  end

  def can_create
    unless @can_create_group_tags
      flash[:error] = 'You do not have permission to create tags for this group.'
      redirect_to @group
    end 
  end

  def group_tag_params
    params.require(:group_tag).permit(PERMITTED_PARAMS)
  end

end
