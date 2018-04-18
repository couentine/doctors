class Api::V1::GroupsController < Api::V1::BaseController

  #=== CONSTANTS ===#

  SORT_FIELDS = {
    admin_count: :admin_count,
    color: :color,
    created_at: :created_at,
    location: :location,
    member_count: :member_count,
    name: :name, 
    total_user_count: :total_user_count,
    type: :type
  }
  DEFAULT_SORT_FIELD = :name
  DEFAULT_SORT_ORDER = :asc

  DEFAULT_FILTER = {
    status: 'all'
  }

  #=== ACTIONS ===#

  # This can be accessed via the groups index (only available to logged in users) or via the user groups index (available to anyone who
  # can see that user).
  def index
    # Determine mode we are in (user group index or my group index), then authorize the appropriate policy
    if params[:user_id].present?
      @user = User.find(params[:user_id]) rescue nil
      @public_only = true
      if @user
        authorize @user, :groups_index? # authorizes the groups index on this specific user
      else
        skip_authorization

        return render_not_found
      end
    else
      @user = @current_user
      @public_only = false
      authorize :group # authorizes the "my groups" index for the current user
    end

    # Build the core criteria based on the filter
    load_filter
    if @filter[:status] == 'member'
      if @public_only
        group_criteria = @user.member_of.where(member_visibility: 'public')
      else
        group_criteria = @user.member_of
      end
    elsif @filter[:status] == 'admin'
      if @public_only
        group_criteria = @user.admin_of.where(admin_visibility: 'public')
      else
        group_criteria = @user.admin_of
      end
    else
      group_criteria = @user.groups(@public_only)
    end
    
    # Generate @sort_string from the sort parameter and load the pagination variables
    build_sort_string
    set_initial_pagination_variables

    # Generate the final query and then generate the calculated pagination variables
    @groups = group_criteria.order_by(@sort_string).page(@page[:number]).per(@page[:size])
    set_calculated_pagination_variables(@groups)

    @policy = Pundit.policy(@current_user, @groups)
    render_json_api @groups, expose: { meta_index: @policy.meta_index }
  end

  def show
    @group = Group.find(params[:id]) rescue nil

    if @group
      authorize @group

      @policy = Pundit.policy(@current_user, @group)
      render_json_api @group, expose: { meta: @policy.meta }
    else
      skip_authorization

      render_not_found
    end
  end

end