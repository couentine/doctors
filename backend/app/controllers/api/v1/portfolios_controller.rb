class Api::V1::PortfoliosController < Api::V1::BaseController

  #=== CONSTANTS ===#

  SORT_FIELDS = {
    status: :validation_status,
    user_name: :user_name,
    date_started: :date_started,
    date_requested: :date_requested,
    date_withdrawn: :date_withdrawn,
    date_issued: :date_issued,
    date_retracted: :date_retracted,
    date_originally_issued: :date_originally_issued
  }
  DEFAULT_SORT_FIELD = :user_name
  DEFAULT_SORT_ORDER = :asc

  DEFAULT_FILTER = {
    status: 'all'
  }

  #=== ACTIONS ===#

  # This can be accessed via the the badge portfolios index or the user portfolios index
  def index
    skip_authorization

    if params[:badge_id].present?
      @badge = Badge.find(params[:badge_id])
      return render_not_found if @badge.blank?
      return render_not_authorized if !Pundit.policy(@current_user, @badge).can_see_portfolios?
    else # must be user mode
      @user = User.find(params[:user_id] || params[:email])
      return render_not_found if @user.blank?
      return render_not_authorized if !Pundit.policy(@current_user, @user).can_see_portfolios?
    end
    
    # Build the core criteria based on the filter and the policy scope
    # NOTE: The full_url method which is included in the serializable portfolio definition needs the group, user AND badge
    #   so we include what we can, then expose the rest in the render_json call.
    if @badge.present?
      portfolio_criteria = PortfolioPolicy::BadgeScope.new(@current_user, @badge.logs, @badge).resolve.includes(:user)
    else # must be user mode
      portfolio_criteria = PortfolioPolicy::UserScope.new(@current_user, @user.logs, @user).resolve.includes(badge: :group)
    end

    load_filter
    if @filter[:status] != 'all'
      portfolio_criteria = portfolio_criteria.where(:validation_status.in => Log.status_to_validation_stati(@filter[:status]))
    end
    
    # Generate @sort_string from the sort parameter and load the pagination variables
    build_sort_string
    set_initial_pagination_variables

    # Generate the final query and then generate the calculated pagination variables
    @portfolios = portfolio_criteria.order_by(@sort_string).page(@page[:number]).per(@page[:size])
    set_calculated_pagination_variables(@portfolios)

    if @badge.present?
      @policy = PortfolioPolicy.new(@current_user, @portfolios, expose: { badge: @badge, group: @badge.group })
      render_json_api @portfolios, expose: { policy_index: @policy.policy_index, badge: @badge, group: @badge.group }
    else
      @policy = PortfolioPolicy.new(@current_user, @portfolios, expose: { user: @user })
      render_json_api @portfolios, expose: { policy_index: @policy.policy_index, user: @user }
    end
  end

  # This can be accessed either via the get portfolio path or via the get badge portfolio path
  def show
    skip_authorization
    if params[:badge_id].present?
      @user = User.find(params[:id] || params[:email])
      @portfolio = Log.where(badge_id: params[:badge_id], user_id: @user.id).first if @user.present?
    else
      @portfolio = Log.find(params[:id]) rescue nil
    end
    return render_not_found if @portfolio.blank?

    @policy = PortfolioPolicy.new(@current_user, @portfolio)
    return render_not_authorized if !@policy.show?
    
    render_json_api @portfolio, expose: { policy: @policy }
  end

end