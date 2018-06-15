class Api::V1::AppGroupMembershipsController < Api::V1::BaseController

  #=== CONSTANTS ===#

  SORT_FIELDS = {
    created_at: :created_at,
    updated_at: :updated_at,
    status: :status,
    app_approval_status: :app_approval_status,
    group_approval_status: :group_approval_status,
  }
  DEFAULT_SORT_FIELD = :created_at
  DEFAULT_SORT_ORDER = :desc

  APP_GROUP_MEMBERSHIPS_FILTER = {
    status: 'all',
    app_approval_status: 'all',
    group_approval_status: 'all',
  }

  #=== ACTIONS ===#

  # Accessible via: group index, app index
  def index
    skip_authorization

    # Build the core criteria
    if params[:group_id].present?
      @group = Group.find(params[:group_id])
      return render_not_found if @group.blank?
      return render_not_authorized if !Pundit.policy(@current_user, @group).can_see_app_group_memberships?

      app_group_membership_criteria = @group.app_memberships
    elsif params[:app_id].present?
      @app = App.find(params[:app_id])
      return render_not_found if @app.blank?
      return render_not_authorized if !Pundit.policy(@current_user, @app).can_see_app_group_memberships?
      
      app_group_membership_criteria = @app.group_memberships
    else
      raise ArgumentError.new('Invalid index route!')
    end

    # Build filters
    load_filter APP_GROUP_MEMBERSHIPS_FILTER
    if AppGroupMembership::STATUS_VALUES.include?(@filter[:status])
      app_group_membership_criteria = app_group_membership_criteria.where(status: @filter[:status])
    else
      @filter[:status] = 'all'
    end
    if AppGroupMembership::APPROVAL_STATUS_VALUES.include?(@filter[:app_approval_status])
      app_group_membership_criteria = app_group_membership_criteria.where(app_approval_status: @filter[:app_approval_status])
    else
      @filter[:app_approval_status] = 'all'
    end
    if AppGroupMembership::APPROVAL_STATUS_VALUES.include?(@filter[:group_approval_status])
      app_group_membership_criteria = app_group_membership_criteria.where(group_approval_status: @filter[:group_approval_status])
    else
      @filter[:group_approval_status] = 'all'
    end

    # Generate @sort_string from the sort parameter and load the pagination variables
    build_sort_string
    set_initial_pagination_variables

    # Generate the final query and then generate the calculated pagination variables
    app_group_membership_criteria = \
      app_group_membership_criteria.includes(:group, :app).order_by(@sort_string).page(@page[:number]).per(@page[:size])
    set_calculated_pagination_variables(app_group_membership_criteria)

    @app_group_memberships = app_group_membership_criteria.entries
    @policy = AppGroupMembershipPolicy.new(@current_user, @app_group_memberships)
    render_json_api @app_group_memberships, expose: { policy_index: @policy.policy_index }
  end

  def show
    skip_authorization
    @app_group_membership = AppGroupMembership.find(params[:id]) rescue nil
    return render_not_found if @app_group_membership.blank?

    @policy = Pundit.policy(@current_user, @app_group_membership)
    return render_not_authorized if !@policy.show?

    render_json_api @app_group_membership, expose: { policy: @policy }
  end

  # Accessible only via routes underneath app and underneath group
  # NOTE: If creating from the user side then we need to check the app's group_joinability setting.
  def create
    skip_authorization

    # Find the parent records and authorize the request
    # There will *always* be a parent record, since there is no route for creating an app user membership from the top level
    if params[:group_id].present?
      @group = Group.find(params[:group_id])
      return render_not_found if @group.blank?
      return render_not_authorized if !Pundit.policy(@current_user, @group).create_app_group_membership?

      parent_relationship = :group
    elsif params[:app_id].present?
      @app = App.find(params[:app_id])
      return render_not_found if @app.blank?
      return render_not_authorized if !Pundit.policy(@current_user, @app).create_app_group_membership?
      
      parent_relationship = :app
    else
      raise ArgumentError.new('Invalid creation route!')
    end

    # Deserialize the authentication token and wrap it in the change decorator, then validate it
    @app_group_membership = AppGroupMembershipDecorator::GroupMembershipDecorator.new(
      Api::V1::DeserializableAppGroupMembership.new(
        params, AppGroupMembershipPolicy.get_creation_fields_for(parent_relationship)
      ).app_group_membership
    )
    @app_group_membership.creator = @current_user
    if parent_relationship == :group
      @app_group_membership.group = @group
    else
      @app_group_membership.app = @app
    end
    @app_group_membership.validate

    # The last pre-saving step is only for memberships created from the group relationship. Now that we know the app is present, we can 
    # check the group joinability setting. If it is closed then this app group membership creation request is invalid altogether.
    # If it is by request only then we can create it. If it is open, then we can create it and automatically approve it right now.
    if @app_group_membership.errors.empty? && (parent_relationship == :group)
      if @app_group_membership.app.group_joinability == 'open'
        @app_group_membership.app_approval_status = 'approved'
      elsif @app_group_membership.app.group_joinability == 'by_request'
        @app_group_membership.app_approval_status = 'requested'
      else
        @app_group_membership.errors.add(:base, 'This app has a closed group membership and can only be joined by invitation')
      end
    end

    # Then do the save / render any errors
    if @app_group_membership.errors.empty? && @app_group_membership.save_as(@current_user)
      @policy = Pundit.policy(@current_user, @app_group_membership)
      render_json_api @app_group_membership, status: 201, expose: { policy: @policy }
    else
      render_field_errors @app_group_membership.errors, status: 400
    end
  end

  def update
    skip_authorization
    @app_group_membership = AppGroupMembership.find(params[:id])
    return render_not_found if @app_group_membership.blank?

    @policy = Pundit.policy(@current_user, @app_group_membership)
    return render_not_authorized if !@policy.update?

    # AppGroupMembershiply the field updates from the params and wrap it in the change decorator
    @app_group_membership = AppGroupMembershipDecorator::GroupMembershipDecorator.new(
      Api::V1::DeserializableAppGroupMembership.new(
        params, @policy.current_user_editable_fields, existing_document: @app_group_membership
      ).app_group_membership
    )

    # Then do the save / render any errors, only validate after confirming that there were no deserialization errors added
    if @app_group_membership.errors.empty? && @app_group_membership.valid? && @app_group_membership.save_as(@current_user)
      render_json_api @app_group_membership, status: 200, expose: { policy: @policy }
    else
      render_field_errors @app_group_membership.errors, status: 400
    end
  end

  def destroy
    skip_authorization
    @app_group_membership = AppGroupMembership.find(params[:id])
    return render_not_found if @app_group_membership.blank?
    
    @policy = Pundit.policy(@current_user, @app_group_membership)
    return render_not_authorized if !@policy.destroy?

    @app_group_membership = AppGroupMembershipDecorator::GroupMembershipDecorator.new(@app_group_membership)
    if @app_group_membership.destroy_as(@current_user)
      render_json_api nil, status: 204 # no content
    else
      render_field_errors @app_group_membership.errors, status: 400
    end
  end

end