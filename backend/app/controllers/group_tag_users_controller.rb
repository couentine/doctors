class GroupTagUsersController < ApplicationController
  
  prepend_before_action :find_parent_records
  before_action :authenticate_user!, except: [:index]
  before_action :can_assign, only: [:add, :bulk_create, :destroy]

  # === STANDARD RESTFUL ACTIONS === #

  # JSON only
  # GET /group-url/tags/tag-name/users.json?page=2&page_size=50
  def index
    respond_to do |format|
      format.json do
        # Get pagination variables
        sort_fields = ['name', 'username'] # defaults to first value >> SEE NOTE
        sort_orders = ['asc', 'desc'] # defaults to first value >> SEE NOTE
        #  >> NOTE: If you change the defaults here, also update GroupTagsController#show
        @page_size = params['page_size'] || APP_CONFIG['page_size_normal'] # default to normal
        @page_size = [@page_size, APP_CONFIG['page_size_large']].min # cap it at largest
        @page = (params['page'] || 1).to_i
        @next_page = nil
        @sort_by = (sort_fields.include? params['sort_by']) ? params['sort_by'] : sort_fields.first
        @sort_order = \
          (sort_orders.include? params['sort_order']) ? params['sort_order'] : sort_orders.first

        user_criteria = @group_tag.users.order_by("#{@sort_by} #{@sort_order}")\
          .page(@page).per(@page_size)
        @users_hash = User.array_json(user_criteria, :group_list_item)
        @next_page = @page + 1 if user_criteria.count > (@page_size * @page)

        render json: { page: @page, page_size: @page_size, users: @users_hash, 
          next_page: @next_page }
      end
    end
  end

  # JSON only. Returns 3 keys: success, user, error_message
  # DELETE /group-url/tags/tag-name/users/abc123.json
  def destroy
    respond_to do |format|
      format.json do
        @user = User.find(params['id']) || not_found
        
        begin
          @group_tag.remove_users([@user.id], current_user.id)
          @success = true
          @error_message = nil
        rescue => e
          @success = false
          @error_message = e.to_s
        end

        render json: { success: @success, user: @user.json(:group_list_item), 
          error_message: @error_message }
      end
    end
  end

  # === CUSTOM RESTFUL ACTIONS === #

  # GET /group-url/tags/tag-name/users/add
  def add
    render layout: 'app'
  end

  # If HTML: Redirects to poller
  # If JSON: Returns 2 keys: success and poller_id.
  # POST /group-url/tags/tag-name/users/bulk_create.json?user_ids[]=abc123
  def bulk_create
    user_ids = params['user_ids'] || []
    poller_id = @group_tag.add_users(user_ids, current_user.id, true)
    
    respond_to do |format|
      format.html do
        @poller = Poller.find(poller_id)
        redirect_to @poller
      end
      format.json do
        render json: { success: true, poller_id: poller_id.to_s }
      end
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
    
    @group_tag = @group.tags.find_by(name: params[:tag_id].to_s.downcase) || not_found
  end

  def can_assign
    unless @can_assign_group_tags
      respond_to do |format|
        format.json do
          render json: { success: false, error_message: 'You do not have permission to assign ' \
            + 'this tag to users.' }
        end
      end
    end 
  end

end
