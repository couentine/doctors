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
    @group = Group.find(params[:group_id]) rescue nil

    if @group
      # Build the core criteria and authorize based on the filter
      load_filter
      if @filter[:status] == 'member'
        authorize @group, :members_index?
        user_criteria = @group.members
      elsif @filter[:status] == 'admin'
        authorize @group, :admins_index?
        user_criteria = @group.admins
      else
        authorize @group, :members_and_admins_index?
        user_criteria = @group.users
      end
      
      # Generate @sort_string from the sort parameter and load the pagination variables
      build_sort_string
      set_initial_pagination_variables

      # Generate the final query and then generate the calculated pagination variables
      @users = user_criteria.order_by(@sort_string).page(@page[:number]).per(@page[:size])
      set_calculated_pagination_variables(@users)

      @policy = Pundit.policy(@current_user, @users)
      render_json_api @users, expose: { show_all_fields: true, meta_index: @policy.meta_index }
    else
      skip_authorization

      render_not_found
    end
  end

  def show
    @user = User.find(params[:id] || params[:email])

    if @user
      authorize @user # always returns true, fields are filtered in the serializer
      
      @policy = Pundit.policy(@current_user, @user)
      render_json_api @user, expose: { show_all_fields: @policy.show_all_fields?, meta: @policy.meta }
    else
      skip_authorization

      render_not_found
    end
  end

end