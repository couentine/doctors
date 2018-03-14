#==========================================================================================================================================#
# API BASE CONTROLLER #
#
## Available Controller Variables ##
#
# - @current_user = The currently signed in user.
# - @current_authentication_token = Only set if user is authenticated via the API
# - @authentication_method = :token, :session or :none
#
#==========================================================================================================================================#

class Api::V1::BaseController < ApplicationController
  include Pundit

  #=== FILTERS ===#
  
  before_filter :process_authentication
  after_action :verify_authorized # Enforces the use of Pundit policies by throwing an error if they weren't used on an action
  
  #=== OTHER SETTINGS ===#

  protect_from_forgery with: :null_session

  rescue_from Mongoid::Errors::DocumentNotFound, with: :render_not_found
  rescue_from Pundit::NotAuthorizedError, with: :render_not_authorized
  rescue_from Api::V1::DeserializationError, with: :render_bad_request
  rescue_from ActionController::ParameterMissing, with: :render_bad_request
  
  #=== JSON API RB ===#

  def jsonapi_class 
    { 
      AuthenticationToken: Api::V1::SerializableAuthenticationToken,
      Group: Api::V1::SerializableGroup,
      Badge: Api::V1::SerializableBadge,
      String: Api::V1::SerializableString
    }
  end

  #=== RENDERING METHODS ===#

  # Use this method to render json api output. It automatically sets the metadata as appropriate.
  def render_json_api(data, status: 200, root_meta: {}, expose: {}, include: [])
    render jsonapi: data, 
      status: status, 
      meta: build_root_meta_hash(root_meta), 
      expose: expose,
      include: include
  end

  def render_not_found
    return render_single_error(status: 404, title: 'Not found', detail: 'The specified record could not be found.')
  end

  def render_not_authorized
    return render_single_error(status: 403, title: 'Unauthorized', detail: 'You do not have access to this operation.')
  end

  def render_bad_request(e)
    return render_single_error(status: 400, title: 'Bad request', detail: e.to_s)
  end

  # This renders a JSON API formatted error message from a single string.
  # For rendering a list of active model errors use `render jsonapi_errors: @object.errors`
  def render_single_error(status: 500, title: 'Server error', detail: nil)
    render json: {
      errors: [
        {
          status: status,
          title: title,
          detail: detail
        }
      ]
    }, status: status
  end

  #=== METADATA METHODS ===#

  # This adds in pagination variables and information about the current user as relevant.
  def build_root_meta_hash(custom_meta = {})
    complete_meta = { authentication_method: @authentication_method }.merge(custom_meta)

    complete_meta.merge!(get_pagination_variables) if @page.present?

    return complete_meta
  end

  #=== PAGINATION METHODS ===#

  def get_pagination_variables
    return {
      page: @page,
      page_size: @page_size,
      previous_page: @previous_page,
      next_page: @next_page,
      last_page: @last_page
    }
  end

  def set_initial_pagination_variables
    @page_size = (params['page[size]'] || APP_CONFIG['page_size_small']).to_i
    @page = (params[:page] || 1).to_i
    @previous_page = (@page > 1) ? (@page - 1) : nil
  end
  
  def set_calculated_pagination_variables(query_criteria)
    query_count = query_criteria.count
    
    if query_count > (@page_size * @page)
      @next_page = @page + 1
    else
      @next_page = nil
    end

    @last_page = (query_count / (@page_size.to_f)).ceil
  end

  #=== PRIVATE METHODS ===#

  private
  
  # Authenticates the user if possible and sets controller variables: @current_user, @current_authentication_token, @authentication_method
  def process_authentication
    if @current_user.present?
      @current_authentication_token = nil
      @authentication_method = :session
    else
      user = nil
      matched_authentication_token = nil
      token = params[:token]
      @authentication_method = :none

      if token && (token.length == (AuthenticationToken::MONGO_ID_LENGTH + AuthenticationToken::BODY_LENGTH))
        provided_user_id = token.first(AuthenticationToken::MONGO_ID_LENGTH)
        provided_token_body = token.last(AuthenticationToken::BODY_LENGTH)
        
        user = User.where(id: provided_user_id).first
        if user
          # NOTE: We need to prevent timing attacks, so it's important to use secure_compare rather than querying mongo directly.
          #   Do not refactor this code unless you understand the security implications. (Google 'rails timing attacks api'.)
          user.authentication_tokens.each do |authentication_token|
            if ActiveSupport::SecurityUtils.secure_compare(authentication_token.body, provided_token_body)
              matched_authentication_token = authentication_token
            end
          end
        end

        if matched_authentication_token
          sign_in user, store: false
          matched_authentication_token.track_request!(request)
          
          @current_user = current_user
          @current_authentication_token = matched_authentication_token
          @authentication_method = :token
        end
      end
    end

    # Decorate the current user with permissions (required for Pundit policies to function)
    @current_user = current_user = UserPermissionsDecorator.new(@current_user, @current_authentication_token)
  end

end