class Api::V1::BadgesController < Api::V1::BaseController

  #=== CONSTANTS ===#

  SORT_FIELDS = {
    created_at: :created_at,
    feedback_request_count: :validation_request_count,
    name: :name
  }
  DEFAULT_SORT_FIELD = :name
  DEFAULT_SORT_ORDER = :asc

  MY_BADGES_INDEX_FILTER = {
    status: 'all'
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
    if @group
      badge_criteria = BadgePolicy::GroupScope.new(@current_user, @group.badges, @group).resolve
    else
      load_filter MY_BADGES_INDEX_FILTER
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

  # Accessible via either getBadge or getGroupBadge
  def show
    if params[:group_id].present?
      @badge = Badge.find(params[:group_id] + '.' + params[:id])
    else
      @badge = Badge.find(params[:id])
    end

    if @badge
      authorize @badge # always returns true, fields are filtered in the serializer
      
      @policy = Pundit.policy(@current_user, @badge)
      render_json_api @badge, expose: { show_all_fields: @policy.show_all_fields?, meta: @policy.meta }
    else
      skip_authorization

      render_not_found
    end
  end

end