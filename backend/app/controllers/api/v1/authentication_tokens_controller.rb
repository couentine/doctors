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

  def index
    authorize :authentication_token

    # Build the core criteria (note: there are no filters for authentication tokens)
    authentication_token_criteria = @current_user.authentication_tokens

    # Generate @sort_string from the sort parameter and load the pagination variables
    build_sort_string
    set_initial_pagination_variables

    # Generate the final query and then generate the calculated pagination variables
    @authentication_tokens = authentication_token_criteria.order_by(@sort_string).page(@page[:number]).per(@page[:size])
    set_calculated_pagination_variables(@authentication_tokens)

    @policy = Pundit.policy(@current_user, @authentication_tokens)
    render_json_api @authentication_tokens, expose: { meta_index: @policy.meta_index }
  end

  def show
    @authentication_token = AuthenticationToken.find(params[:id])

    if @authentication_token
      authorize @authentication_token

      @policy = Pundit.policy(@current_user, @authentication_token)
      render_json_api @authentication_token, expose: { meta: @policy.meta }
    else
      skip_authorization

      render_not_found
    end
  end

  def create
    authorize :authentication_token

    creation_service = AuthenticationTokenCreationService.new(1, @current_user, params)
    creation_service.perform
    @authentication_token = creation_service.authentication_token
    
    if creation_service.save_successful
      @policy = Pundit.policy(@current_user, @authentication_token)
      render_json_api @authentication_token, status: 201, expose: { meta: @policy.meta }
    else
      render_field_errors @authentication_token.errors, status: 400
    end
  end

  def destroy
    authorize :authentication_token

    @authentication_token = @current_user.authentication_tokens.where(id: params[:id]).first
    
    if @authentication_token
      if @authentication_token.destroy
        render_json_api nil, status: 204 # no content
      else
        render_field_errors @authentication_token.errors, status: 400
      end
    else
      render_not_found
    end
  end

end