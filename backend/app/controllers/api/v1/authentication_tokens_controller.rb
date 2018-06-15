class Api::V1::AuthenticationTokensController < Api::V1::BaseController

  #=== CONSTANTS ===#

  SORT_FIELDS = {
    created_at: :created_at,
    last_used_at: :last_used_at,
    request_count: :request_count
  }
  DEFAULT_SORT_FIELD = :last_used_at
  DEFAULT_SORT_ORDER = :desc

  #=== ACTIONS ===#

  # Accessible via user index or current user index
  def index
    skip_authorization

    # Determine mode we are in (user group index or my group index), then authorize the appropriate policy
    if params[:user_id].present?
      @user = User.find(params[:user_id])
      return render_not_found if @user.blank?
      return render_not_authorized if !Pundit.policy(@current_user, @user).can_see_authentication_tokens?
      return render_not_authorized if !Pundit.policy(@current_user, @user).can_see_authentication_tokens?
    else
      @user = @current_user
      return render_not_authorized if !Pundit.policy(@current_user, :authentication_token).index?
    end

    # Build the core criteria (note: there are no filters for authentication tokens)
    authentication_token_criteria = @user.authentication_tokens

    # Generate @sort_string from the sort parameter and load the pagination variables
    build_sort_string
    set_initial_pagination_variables

    # Generate the final query and then generate the calculated pagination variables
    authentication_token_criteria = \
      authentication_token_criteria.includes(:user).order_by(@sort_string).page(@page[:number]).per(@page[:size])
    set_calculated_pagination_variables(authentication_token_criteria)

    @authentication_tokens = authentication_token_criteria.entries
    @policy = AuthenticationTokenPolicy.new(@current_user, @authentication_tokens)
    render_json_api @authentication_tokens, expose: { policy_index: @policy.policy_index }
  end

  def show
    skip_authorization
    @authentication_token = AuthenticationToken.find(params[:id])
    return render_not_found if @authentication_token.blank?

    @policy = Pundit.policy(@current_user, @authentication_token)
    return render_not_authorized if !@policy.show?

    render_json_api @authentication_token, expose: { policy: @policy }
  end

  def create
    authorize :authentication_token

    # Deserialize the authentication token
    @authentication_token = Api::V1::DeserializableAuthenticationToken.new(
      params, AuthenticationTokenPolicy.get_creation_fields_for(:creator)
    ).authentication_token

    # Now validate that this user has permission to create a token for this user
    @authentication_token.creator = @current_user
    if @authentication_token.valid?
      if Pundit.policy(@current_user, @authentication_token.user).create_authentication_token?
        @policy = Pundit.policy(@current_user, @authentication_token)
      else
        @authentication_token.errors.add(:user_id, 'You do not have permission to create authentication tokens on behalf of this user')
      end
    end

    # Then do the save / render any errors
    if @authentication_token.errors.empty? && @authentication_token.save
      render_json_api @authentication_token, status: 201, expose: { policy: @policy }
    else
      render_field_errors @authentication_token.errors, status: 400
    end
  end

  def update
    skip_authorization
    @authentication_token = AuthenticationToken.find(params[:id])
    return render_not_found if @authentication_token.blank?

    @policy = Pundit.policy(@current_user, @authentication_token)
    return render_not_authorized if !@policy.update?

    # Apply the field updates from the params
    @authentication_token = Api::V1::DeserializableAuthenticationToken.new(
      params, @policy.current_user_editable_fields, 
      existing_document: @authentication_token
    ).authentication_token

    # Then do the save / render any errors
    if @authentication_token.errors.empty? && @authentication_token.save
      render_json_api @authentication_token, status: 200, expose: { policy: @policy }
    else
      render_field_errors @authentication_token.errors, status: 400
    end
  end

  def destroy
    skip_authorization
    @authentication_token = AuthenticationToken.find(params[:id])
    return render_not_found if @authentication_token.blank?
    
    @policy = Pundit.policy(@current_user, @authentication_token)
    return render_not_authorized if !@policy.destroy?

    if @authentication_token.destroy
      render_json_api nil, status: 204 # no content
    else
      render_field_errors @authentication_token.errors, status: 400
    end
  end

end