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

  def index
    authorize :group # rejects if current user is blank

    # Build the core criteria based on the filter
    load_filter
    if @filter[:status] == 'member'
      group_criteria = @current_user.member_of
    elsif @filter[:status] == 'admin'
      group_criteria = @current_user.admin_of
    else
      group_criteria = @current_user.groups(false) # public_only = false
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