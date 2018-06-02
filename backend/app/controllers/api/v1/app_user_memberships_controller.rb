class Api::V1::AppUserMembershipsController < Api::V1::BaseController

  #=== CONSTANTS ===#

  SORT_FIELDS = {
    created_at: :created_at,
    updated_at: :updated_at,
    type: :type,
    status: :status,
    app_approval_status: :app_approval_status,
    user_approval_status: :user_approval_status,
  }
  DEFAULT_SORT_FIELD = :created_at
  DEFAULT_SORT_ORDER = :desc

  APP_USER_MEMBERSHIPS_FILTER = {
    type: 'all',
    status: 'all',
    app_approval_status: 'all',
    user_approval_status: 'all',
  }

  #=== ACTIONS ===#

  # Accessible via: current user index, user index, app index
  def index
    skip_authorization

    # Build the core criteria
    if params[:user_id].present?
      @user = User.find(params[:user_id])
      return render_not_found if @user.blank?
      return render_not_authorized if !Pundit.policy(@current_user, @user).can_see_app_user_memberships?

      app_user_membership_criteria = @user.app_memberships
    elsif params[:app_id].present?
      @app = App.find(params[:app_id])
      return render_not_found if @app.blank?
      return render_not_authorized if !Pundit.policy(@current_user, @app).can_see_app_user_memberships?
      
      app_user_membership_criteria = @app.user_memberships
    else
      authorize :app_user_membership
      
      app_user_membership_criteria = @current_user.app_memberships
    end

    # Build filters
    load_filter APP_USER_MEMBERSHIPS_FILTER
    if AppUserMembership::TYPE_VALUES.include?(@filter[:type])
      app_user_membership_criteria = app_user_membership_criteria.where(type: @filter[:type])
    else
      @filter[:type] = 'all'
    end
    if AppUserMembership::STATUS_VALUES.include?(@filter[:status])
      app_user_membership_criteria = app_user_membership_criteria.where(status: @filter[:status])
    else
      @filter[:status] = 'all'
    end
    if AppUserMembership::APPROVAL_STATUS_VALUES.include?(@filter[:app_approval_status])
      app_user_membership_criteria = app_user_membership_criteria.where(app_approval_status: @filter[:app_approval_status])
    else
      @filter[:app_approval_status] = 'all'
    end
    if AppUserMembership::APPROVAL_STATUS_VALUES.include?(@filter[:user_approval_status])
      app_user_membership_criteria = app_user_membership_criteria.where(user_approval_status: @filter[:user_approval_status])
    else
      @filter[:user_approval_status] = 'all'
    end

    # Generate @sort_string from the sort parameter and load the pagination variables
    build_sort_string
    set_initial_pagination_variables

    # Generate the final query and then generate the calculated pagination variables
    @app_user_memberships = \
      app_user_membership_criteria.includes(:user, :app).order_by(@sort_string).page(@page[:number]).per(@page[:size])
    set_calculated_pagination_variables(@app_user_memberships)

    @policy = Pundit.policy(@current_user, @app_user_memberships)
    render_json_api @app_user_memberships, expose: { policy_index: @policy.policy_index }
  end

  def show
    skip_authorization
    @app_user_membership = AppUserMembership.find(params[:id]) rescue nil
    return render_not_found if @app_user_membership.blank?

    @policy = Pundit.policy(@current_user, @app_user_membership)
    return render_not_authorized if !@policy.show?

    render_json_api @app_user_membership, expose: { policy: @policy }
  end

  # Accessible only via routes underneath app and underneath user
  # NOTE: If creating from the user side then we need to check the app's user_joinability setting.
  def create
    skip_authorization

    # Find the parent records and authorize the request
    # There will *always* be a parent record, since there is no route for creating an app user membership from the top level
    if params[:user_id].present?
      @user = User.find(params[:user_id])
      return render_not_found if @user.blank?
      return render_not_authorized if !Pundit.policy(@current_user, @user).create_app_user_membership?

      parent_relationship = :user
    elsif params[:app_id].present?
      @app = App.find(params[:app_id])
      return render_not_found if @app.blank?
      return render_not_authorized if !Pundit.policy(@current_user, @app).create_app_user_membership?
      
      parent_relationship = :app
    else
      raise ArgumentError.new('Invalid creation route!')
    end

    # Deserialize the authentication token and wrap it in the change decorator, then validate it
    @app_user_membership = AppUserMembershipDecorator::UserMembershipDecorator.new(
      Api::V1::DeserializableAppUserMembership.new(
        params, AppUserMembershipPolicy.get_creation_fields_for(parent_relationship)
      ).app_user_membership
    )
    @app_user_membership.creator = @current_user
    if parent_relationship == :user
      @app_user_membership.user = @user
    else
      @app_user_membership.app = @app
    end
    @app_user_membership.validate

    # The last step is to check that the app can actually be joined by outside users. This is only needed if the membership is being 
    # created from the user side. If the membership is created from the app side then this user is an admin of the app.
    if @app_user_membership.errors.empty? && (parent_relationship == :user) \
        && !Pundit.policy(@current_user, @app_user_membership.app).join_as_user?
      @app_user_membership.errors.add(:base, 'This app has a closed user membership and can only be joined by invitation')
    end

    # Then do the save / render any errors
    if @app_user_membership.errors.empty? && @app_user_membership.save_as(@current_user)
      @policy = Pundit.policy(@current_user, @app_user_membership)
      render_json_api @app_user_membership, status: 201, expose: { policy: @policy }
    else
      render_field_errors @app_user_membership.errors, status: 400
    end
  end

  def update
    skip_authorization
    @app_user_membership = AppUserMembership.find(params[:id])
    return render_not_found if @app_user_membership.blank?

    @policy = Pundit.policy(@current_user, @app_user_membership)
    return render_not_authorized if !@policy.update?

    # AppUserMembershiply the field updates from the params and wrap it in the change decorator
    @app = AppUserMembershipDecorator::UserMembershipDecorator.new(
      Api::V1::DeserializableAppUserMembership.new(
        params, @policy.current_user_editable_fields, existing_document: @app_user_membership
      ).app_user_membership
    )

    # Then do the save / render any errors, only validate after confirming that there were no deserialization errors added
    if @app_user_membership.errors.empty? && @app_user_membership.valid? && @app_user_membership.save_as(@current_user)
      render_json_api @app_user_membership, status: 200, expose: { policy: @policy }
    else
      render_field_errors @app_user_membership.errors, status: 400
    end
  end

  def destroy
    skip_authorization
    @app_user_membership = AppUserMembership.find(params[:id])
    return render_not_found if @app_user_membership.blank?
    
    @policy = Pundit.policy(@current_user, @app_user_membership)
    return render_not_authorized if !@policy.destroy?

    @app_user_membership = AppUserMembershipDecorator::UserMembershipDecorator.new(@app_user_membership)
    if @app_user_membership.destroy_as(@current_user)
      render_json_api nil, status: 204 # no content
    else
      render_field_errors @app_user_membership.errors, status: 400
    end
  end

end