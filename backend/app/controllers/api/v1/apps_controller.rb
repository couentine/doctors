class Api::V1::AppsController < Api::V1::BaseController

  #=== CONSTANTS ===#

  SORT_FIELDS = {
    name: :name,
    created_at: :created_at,
    user_count: :user_count,
    group_count: :group_count,
    user_joinability: :user_joinability,
    group_joinability: :group_joinability,
    status: :status,
  }
  DEFAULT_SORT_FIELD = :name
  DEFAULT_SORT_ORDER = :asc

  APPS_FILTER = {
    user_joinability: 'all',
    group_joinability: 'all',
    status: 'all',
  }

  #=== ACTIONS ===#

  # Accessible via: current user index, user index, group index
  def index
    skip_authorization

    # Build the core criteria
    if params[:user_id].present?
      @user = User.find(params[:user_id])
      return render_not_found if @user.blank?
      return render_not_authorized if !Pundit.policy(@current_user, @user).can_see_apps?

      app_criteria = @user.apps
    elsif params[:group_id].present?
      @group = Group.find(params[:group_id])
      return render_not_found if @group.blank?
      return render_not_authorized if !Pundit.policy(@current_user, @group).can_see_apps?
      
      app_criteria = @group.apps
    else
      authorize :app
      
      app_criteria = @current_user.apps
    end

    # Build filters
    load_filter APPS_FILTER
    if App::JOINABILITY_VALUES.include?(@filter[:user_joinability])
      app_criteria = app_criteria.where(user_joinability: @filter[:user_joinability])
    else
      @filter[:user_joinability] = 'all'
    end
    if App::JOINABILITY_VALUES.include?(@filter[:group_joinability])
      app_criteria = app_criteria.where(group_joinability: @filter[:group_joinability])
    else
      @filter[:group_joinability] = 'all'
    end
    if App::STATUS_VALUES.include?(@filter[:status])
      app_criteria = app_criteria.where(status: @filter[:status])
    else
      @filter[:status] = 'all'
    end

    # Generate @sort_string from the sort parameter and load the pagination variables
    build_sort_string
    set_initial_pagination_variables

    # Generate the final query and then generate the calculated pagination variables
    @apps = app_criteria.order_by(@sort_string).page(@page[:number]).per(@page[:size])
    set_calculated_pagination_variables(@apps)

    @policy = Pundit.policy(@current_user, @apps)
    render_json_api @apps, expose: { policy_index: @policy.policy_index }
  end

  def show
    skip_authorization
    @app = App.find(params[:id])
    return render_not_found if @app.blank?

    @policy = Pundit.policy(@current_user, @app)
    return render_not_authorized if !@policy.show?

    render_json_api @app, expose: { policy: @policy }
  end

  def create
    authorize :app

    # Deserialize the authentication token and wrap it in the change decorator, then validate it
    @app = AppChangeDecorator.new(Api::V1::DeserializableApp.new(params, AppPolicy.get_creation_fields_for(:creator)).app)
    @app.owner = @current_user
    @app.creator = @current_user
    @app.validate

    # Then do the save / render any errors
    if @app.errors.empty? && @app.save_as(@current_user)
      @policy = Pundit.policy(@current_user, @app)
      render_json_api @app, status: 201, expose: { policy: @policy }
    else
      render_field_errors @app.errors, status: 400
    end
  end

  def update
    skip_authorization
    @app = App.find(params[:id])
    return render_not_found if @app.blank?

    @policy = Pundit.policy(@current_user, @app)
    return render_not_authorized if !@policy.update?

    # Apply the field updates from the params and wrap it in the change decorator
    @app = AppChangeDecorator.new(
      Api::V1::DeserializableApp.new(
        params, @policy.current_user_editable_fields, existing_document: @app
      ).app
    )

    # Then do the save / render any errors, only validate after confirming that there were no deserialization errors added
    if @app.errors.empty? && @app.valid? && @app.save_as(@current_user)
      render_json_api @app, status: 200, expose: { policy: @policy }
    else
      render_field_errors @app.errors, status: 400
    end
  end

  def destroy
    skip_authorization
    @app = App.find(params[:id])
    return render_not_found if @app.blank?
    
    @policy = Pundit.policy(@current_user, @app)
    return render_not_authorized if !@policy.destroy?

    @app = AppChangeDecorator.new(@app)
    if @app.destroy
      render_json_api nil, status: 204 # no content
    else
      render_field_errors @app.errors, status: 400
    end
  end

end