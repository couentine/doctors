class Api::V1::AuthenticationTokensController < Api::V1::BaseController

  def index
    set_initial_pagination_variables
    if current_user
      @authentication_tokens = current_user.authentication_tokens.desc(:last_used_at).page(@page).per(@page_size)
    else
      @authentication_tokens = []
    end
    set_calculated_pagination_variables(@authentication_tokens)

    if current_user
      render_json_api @authentication_tokens
    else
      render_single_error title: 'Unauthorized', detail: 'You must be logged in to view API tokens.', status: 401
    end
  end

  def show
    @authentication_token = AuthenticationToken.find(params[:id])

    if @authentication_token
      render_json_api @authentication_token
    else
      render_not_found
    end
  end

  def create
    if current_user
      @authentication_token = current_user.authentication_tokens.new
      
      if @authentication_token.save
        render_json_api @authentication_token, status: 201
      else
        render jsonapi_errors: @authentication_token.errors, status: 400
      end
    else
      render_single_error title: 'Unauthorized', detail: 'You must be logged in to create an API token.', status: 401
    end
  end

  def destroy
    if current_user
      @authentication_token = current_user.authentication_tokens.find_by(id: params[:id])
      
      if @authentication_token.destroy
        render_json_api nil, status: 204 # no content
      else
        render jsonapi_errors: @authentication_token.errors, status: 400
      end
    else
      render_single_error title: 'Unauthorized', detail: 'You must be logged in to delete an API token.', status: 401
    end
  end

end