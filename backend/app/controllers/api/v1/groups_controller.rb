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

  # This can be accessed via the groups index, the user groups index and the app groups index.
  def index
    skip_authorization

    if params[:app_id].present?
      @app = App.find(params[:app_id]) rescue nil
      return render_not_found if @app.blank?
      return render_not_authorized if !Pundit.policy(@current_user, @app).can_see_groups?

      group_criteria = @app.groups
    else
      if params[:user_id].present? || params[:email].present?
        @user = User.find(params[:user_id] || params[:email])
        return render_not_found if @user.blank?
        return render_not_authorized if !Pundit.policy(@current_user, @user).can_see_groups?
      else
        @user = @current_user
        return render_not_authorized if !Pundit.policy(@current_user, :group).index?
      end

      # Build the core criteria based on the filter (filters are only for user mode)
      load_filter
      group_criteria = GroupPolicy::UserScope.new(@current_user, @filter[:status], @user).resolve
    end

    # Generate @sort_string from the sort parameter and load the pagination variables
    build_sort_string
    set_initial_pagination_variables

    # Generate the final query and then generate the calculated pagination variables
    @groups = group_criteria.order_by(@sort_string).page(@page[:number]).per(@page[:size])
    set_calculated_pagination_variables(@groups)

    @policy = Pundit.policy(@current_user, @groups)
    render_json_api @groups, expose: { policy_index: @policy.policy_index }
  end

  def show
    skip_authorization
    @group = Group.find(params[:id])
    return render_not_found if @group.blank?

    @policy = Pundit.policy(@current_user, @group)
    return render_not_authorized if !@policy.show?
    
    render_json_api @group, expose: { policy: @policy }
  end

end