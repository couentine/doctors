class Api::V1::AuthenticationTokensController < Api::V1::BaseController

  #=== API ACCESS MAP ===#

  @accessible_actions = {
    internal_user: [:index, :show, :create, :destroy],
    external_user: [],
    group_user: [:index, :show, :create, :destroy],
    public: [:index, :show, :create, :destroy]
  }

  #=== ACTIONS ===#

  def index
    authorize :authentication_token

    set_initial_pagination_variables
    @authentication_tokens = @current_user.authentication_tokens.desc(:last_used_at).page(@page).per(@page_size)
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
      render jsonapi_errors: @authentication_token.errors, status: 400
    end
  end

  def destroy
    authorize :authentication_token

    @authentication_token = @current_user.authentication_tokens.where(id: params[:id]).first
    
    if @authentication_token
      if @authentication_token.destroy
        render_json_api nil, status: 204 # no content
      else
        render jsonapi_errors: @authentication_token.errors, status: 400
      end
    else
      render_not_found
    end
  end

end