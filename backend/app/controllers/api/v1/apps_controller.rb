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