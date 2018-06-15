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
    skip_authorization

    # Determine mode we are in (group badge index or my badge index), then authorize the appropriate policy and build query
    if params[:group_id].present?
      @group = Group.find(params[:group_id])
      return render_not_found if @group.blank?
      return render_not_authorized if !Pundit.policy(@current_user, @group).can_see_badges?
      
      badge_criteria = BadgePolicy::GroupScope.new(@current_user, @group.badges, @group).resolve.includes(:group)
    else
      return render_not_authorized if !Pundit.policy(@current_user, :badge).index?
      
      load_filter MY_BADGES_INDEX_FILTER
      if @filter[:status] == 'seeker'
        badge_criteria = Badge.where(:id.in => @current_user.learner_badge_ids).includes(:group)
      elsif @filter[:status] == 'holder'
        badge_criteria = Badge.where(:id.in => @current_user.expert_badge_ids).includes(:group)
      else
        badge_criteria = Badge.where(:id.in => @current_user.all_badge_ids).includes(:group)
      end
    end
    
    # Generate @sort_string from the sort parameter and load the pagination variables
    build_sort_string
    set_initial_pagination_variables

    # Generate the final query and then generate the calculated pagination variables
    badge_criteria = badge_criteria.order_by(@sort_string).page(@page[:number]).per(@page[:size])
    set_calculated_pagination_variables(badge_criteria)
    @badges = badge_criteria.entries

    @policy = BadgePolicy.new(@current_user, @badges)
    render_json_api @badges, expose: { policy_index: @policy.policy_index }
  end

  # Accessible via either getBadge or getGroupBadge
  def show
    skip_authorization
    if params[:group_id].present?
      @badge = Badge.find(params[:group_id] + '.' + params[:id])
    else
      @badge = Badge.find(params[:id])
    end
    return render_not_found if @badge.blank?

    @policy = Pundit.policy(@current_user, @badge)
    return render_not_authorized if !@policy.show?

    render_json_api @badge, expose: { policy: @policy }
  end

end