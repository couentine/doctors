class Api::V1::UsersController < Api::V1::BaseController

  #=== CONSTANTS ===#

  SORT_FIELDS = {
    created_at: :created_at,
    last_active: :last_active,
    name: :name,
    username: :username
  }
  DEFAULT_SORT_FIELD = :name
  DEFAULT_SORT_ORDER = :asc

  DEFAULT_FILTER = {
    status: 'all'
  }

  #=== ACTIONS ===#

  # This can be accessed only via the group users index
  def index
    skip_authorization

    if params[:group_id].present?
      @group = Group.find(params[:group_id]) rescue nil
      return render_not_found if @group.blank?

      # Build the core criteria and authorize based on the filter
      load_filter
      if @filter[:status] == 'member'
        return render_not_authorized if !Pundit.policy(@current_user, @group).members_index?
        user_criteria = @group.members
      elsif @filter[:status] == 'admin'
        return render_not_authorized if !Pundit.policy(@current_user, @group).admins_index?
        user_criteria = @group.admins
      else
        return render_not_authorized if !Pundit.policy(@current_user, @group).can_see_users?
        user_criteria = @group.users
      end
    else
      raise ArgumentError.new('Invalid user index route')
    end
    
    # Generate @sort_string from the sort parameter and load the pagination variables
    build_sort_string
    set_initial_pagination_variables

    # Generate the final query and then generate the calculated pagination variables
    user_criteria = user_criteria.order_by(@sort_string).page(@page[:number]).per(@page[:size])
    set_calculated_pagination_variables(user_criteria)

    @users = user_criteria.entries
    @policy = UserPolicy.new(@current_user, @users)
    render_json_api @users, expose: { policy_index: @policy.policy_index }
  end

  def show
    skip_authorization
    @user = User.find(params[:id] || params[:email])
    return render_not_found if @user.blank?
      
    @policy = Pundit.policy(@current_user, @user)
    return render_not_authorized if !@policy.show?

    render_json_api @user, expose: { policy: @policy }
  end

end