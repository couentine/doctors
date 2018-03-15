class Api::V1::BadgesController < Api::V1::BaseController

  #=== CONSTANTS ===#

  SORT_FIELDS = {
    name: :name, 
    created_at: :created_at,
    feedback_request_count: :validation_request_count
  }
  DEFAULT_SORT_FIELD = :name
  DEFAULT_SORT_ORDER = :asc

  DEFAULT_FILTER = {
    status: 'all'
  }

  #=== ACTIONS ===#

  def index
    authorize :badge # rejects if current user is blank

    # Build the core criteria based on the filter
    load_filter
    if @filter[:status] == 'seeker'
      badge_criteria = Badge.where(:id.in => @current_user.learner_badge_ids)
    elsif @filter[:status] == 'holder'
      badge_criteria = Badge.where(:id.in => @current_user.expert_badge_ids)
    else
      badge_criteria = Badge.where(:id.in => @current_user.all_badge_ids)
    end
    
    # Generate @sort_string from the sort parameter and load the pagination variables
    build_sort_string
    set_initial_pagination_variables

    # Generate the final query and then generate the calculated pagination variables
    @badges = badge_criteria.order_by(@sort_string).page(@page).per(@page_size)
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