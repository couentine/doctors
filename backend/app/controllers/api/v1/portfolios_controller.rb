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
    if params[:badge_id].present?
      @badge = Badge.find(params[:badge_id])
      
      if @badge
        authorize @badge, :portfolios_index?
      else
        skip_authorization
        return render_not_found
      end
    else # must be user mode
      @user = User.find(params[:user_id] || params[:email])

      if @user
        authorize @user, :portfolios_index?
      else
        skip_authorization
        return render_not_found
      end
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

    @policy = PortfolioPolicy.new(@current_user, @portfolios)
    if @badge.present?
      render_json_api @portfolios, expose: { meta_index: @policy.meta_index, badge: @badge, group: @badge.group }
    else
      render_json_api @portfolios, expose: { meta_index: @policy.meta_index, user: @user }
    end
  end

  # This can be accessed either via the get portfolio path or via the get badge portfolio path
  def show
    if params[:badge_id].present?
      @user = User.find(params[:id] || params[:email])
      @portfolio = Log.where(badge_id: params[:badge_id], user_id: @user.id).first if @user.present?
    else
      @portfolio = Log.find(params[:id]) rescue nil
    end
    skip_authorization

    if @portfolio
      @policy = PortfolioPolicy.new(@current_user, @portfolio)

      if @policy.show?
        render_json_api @portfolio, expose: { meta: @policy.meta }
      else
        render_not_authorized if !@policy.show?
      end
    else
      render_not_found
    end
  end

end