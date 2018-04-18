class Api::V1::BadgesController < Api::V1::BaseController

  #=== CONSTANTS ===#

  SORT_FIELDS = {
    created_at: :created_at,
    feedback_request_count: :validation_request_count,
    name: :name
  }
  DEFAULT_SORT_FIELD = :name
  DEFAULT_SORT_ORDER = :asc

  DEFAULT_FILTER = {
    status: 'all',
    visibility: 'all'
  }

  #=== ACTIONS ===#

  # This can be accessed via the my badges index (only available to logged in users) or via the group badges index (available to anyone who
  # can see that group).
  def index
    # Determine mode we are in (group badge index or my badge index), then authorize the appropriate policy
    if params[:group_id].present?
      @group = Group.find(params[:group_id]) rescue nil
      if @group
        authorize @group, :badges_index?
      else
        skip_authorization

        return render_not_found
      end
    else
      authorize :badge
    end

    # Build the core criteria based on the filter and on the current users permission (if relevant)
    load_filter
    if @group
      if (@filter[:visibility] == 'all') 
        allowed_visibility_values = [:public, :private, :hidden]
      else 
        allowed_visibility_values = [@filter[:visibility]]
      end
      badge_criteria = @group.badges.where(:visibility.in => allowed_visibility_values)

      if @current_user.present? && (@current_user.admin || @current_user.admin_of?(@group))
        badge_criteria = badge_criteria
      elsif @current_user.present? && @current_user.member_of?(@group)
        badge_criteria = badge_criteria.any_of(
          {:visibility.ne => 'hidden'}, 
          {:id.in => @current_user.all_badge_ids}
        )
      else
        badge_criteria = badge_criteria.where(visibility: 'public')
      end
    else
      if @filter[:status] == 'seeker'
        badge_criteria = Badge.where(:id.in => @current_user.learner_badge_ids)
      elsif @filter[:status] == 'holder'
        badge_criteria = Badge.where(:id.in => @current_user.expert_badge_ids)
      else
        badge_criteria = Badge.where(:id.in => @current_user.all_badge_ids)
      end
    end
    
    # Generate @sort_string from the sort parameter and load the pagination variables
    build_sort_string
    set_initial_pagination_variables

    # Generate the final query and then generate the calculated pagination variables
    @badges = badge_criteria.order_by(@sort_string).page(@page[:number]).per(@page[:size])
    set_calculated_pagination_variables(@badges)

    @policy = Pundit.policy(@current_user, @badges)
    render_json_api @badges, expose: { show_all_fields: true, meta_index: @policy.meta_index }
  end

  def show
    if params[:parent_path].present?
      @badge = Badge.find(params[:parent_path] + '.' + params[:id])
    else
      @badge = Badge.find(params[:id])
    end

    # NOTE: This is currently undocumented. Also we need to check that the authentication token has permission to read groups.
    if params[:include] == 'group'
      @include = [:group]
    else
      @include = nil
    end

    if @badge
      authorize @badge # always returns true, fields are filtered in the serializer
      
      @policy = Pundit.policy(@current_user, @badge)
      render_json_api @badge, expose: { show_all_fields: @policy.show_all_fields?, meta: @policy.meta }, include: @include
    else
      skip_authorization

      render_not_found
    end
  end

end