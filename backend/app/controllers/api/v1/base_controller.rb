#==========================================================================================================================================#
# API BASE CONTROLLER #
#
## Available Controller Variables ##
#
# - @api_access = :public, :internal_user, :external_user, :group_user
# - @current_user = The currently signed in user. (Set for all non-public api access.)
# - @current_group = The currently signed in group. (Set only for group-user api access.)
#
#==========================================================================================================================================#

class Api::V1::BaseController < ApplicationController

  #=== FILTERS ===#
  
  before_filter :process_authentication!
  
  #=== OTHER SETTINGS ===#

  protect_from_forgery with: :null_session
  rescue_from Mongoid::Errors::DocumentNotFound, with: :render_not_found
  
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
  def render_json_api(data, status: 200, meta: {})
    render jsonapi: data, status: status, meta: build_meta_hash(meta)
  end

  def render_not_found
    return render_single_error(status: 404, title: 'Not found.')
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
  def build_meta_hash(custom_meta = {})
    complete_meta = { api_access: @api_access }.merge(custom_meta)

    complete_meta.merge!({ current_user: @current_user }) if @current_user.present?
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
    @page_size = (params['page_size'] || APP_CONFIG['page_size_small']).to_i
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
  
  # Authenticates the user if possible and sets the @current_user and @api_access variables.
  # If the user has already been authenticated from the session, then that is left as is, otherwise an attempt is made to authenticate
  # via the `token` parameter. If that fails then we are in public mode. (FIXME.. explain this better)
  def process_authentication!
    if @current_user.present?
      @api_access = :internal_user
    else
      user = nil
      matched_authentication_token = nil
      token = params[:token]
      @api_access = :public # default value

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
          @api_access = :external_user
        end
      end
    end
  end

end