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
  
  #=== CONSTANTS ===#

  MIN_PAGE_SIZE = 1
  MAX_PAGE_SIZE = 200
  
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
  # For rendering a list of active model errors use the `render_field_errors` method below
  def render_single_error(status: 500, title: 'Server error', detail: nil)
    render json: {
      errors: [
        {
          status: status,
          title: title,
          detail: detail
        }
      ],
      jsonapi: {
        version: '1.0'
      }
    }, status: status
  end

  # This renders a JSON API formatted error message from an instance of ActiveModel::Errors
  # Example Usage: `render_field_errors @object.errors, status: 400`
  def render_field_errors(active_model_errors, status: 400)
    render json: {
      errors: active_model_errors.to_hash.map do |field_key, error_messages|
        {
          title: "Invalid #{field_key}",
          detail: error_messages.join('. '),
          source: {
            pointer: "/data/attributes/#{field_key}"
          }
        }
      end,
      jsonapi: {
        version: '1.0'
      }
    }, status: status
  end

  #=== METADATA METHODS ===#

  # This adds in pagination variables and information about the current user as relevant.
  def build_root_meta_hash(custom_meta = {})
    complete_meta = { authentication_method: @authentication_method }.merge(custom_meta)

    complete_meta[:page] = @page if @page.present?
    complete_meta[:sort] = @external_sort_string if @external_sort_string.present?
    complete_meta[:filter] = @filter if @filter.present?

    return complete_meta
  end

  #=== PARAMETER METHODS ===#

  # This loads any of the 'filter[xxx]' page parameters into the @filter variable, cleanses the keys and sets defaults.
  # NOTE: This will automatically cause the filter to be included in the response meta.
  # This depends on the presence of a DEFAULT_FILTER constant in the subclass which should be a hash with a symbol key for each filter key 
  # and a string value for the default if that filter key isn't present in the params.
  def load_filter
    filter_param = params[:filter] || {}
    @filter = {}
    self.class::DEFAULT_FILTER.each do |key, value|
      if filter_param[key.to_s].present?
        @filter[key] = filter_param[key.to_s]
      else
        @filter[key] = value
      end
    end
  end

  # Builds out @sort_string to be a string of the format `field_name ASC, other_field_name DESC`
  # This depends on the presence of three constants in the subclass: 
  # - SORT_FIELDS, = A field mapping hash with keys for each valid sort field that a user can enter and values for the corresponding
  #   database field (they can be the same, but do not need to be).
  # - DEFAULT_SORT_FIELD = The key from the SORT_FIELDS map representing the default field.
  # - DEFAULT_SORT_ORDER = :asc or :desc
  def build_sort_string
    if params[:sort].present?
      valid_sort_items = params[:sort].downcase.split(',').map do |item|
        # Generate a hash including which parses out all core details
        external_field = item.strip.gsub(/[^a-z_]/, '').to_sym
        {
          external_field: external_field, # the field name as presented to api consumers
          internal_field: self.class::SORT_FIELDS[external_field], # the internal db field (or nil if this isn't an allowed sort field)
          sort: (item.strip.starts_with?('-') ? 'DESC' : 'ASC') # decodes JSON API's sort order syntax (asc is default, hyphen means desc)
        }
      end.select do |item|
        # Filter out any fields which aren't contained in the field mapping
        item[:internal_field].present?
      end.uniq do |item|
        # Filter out duplicates of the same field
        item[:internal_field]
      end

      # Generate the internal sort string (ready for mongoid / origin)
      @sort_string = valid_sort_items.map do |item|
        "#{item[:internal_field].to_s} #{item[:sort]}"
      end.join(', ')
      
      # Then generate the external sort string (which will be included in the response meta)
      @external_sort_string = valid_sort_items.map do |item|
        ((item[:sort] == 'DESC') ? '-' : '') + item[:external_field].to_s
      end.join(',')
    end

    if @sort_string.blank?
      # Either there was no sort parameter or the sort parameter was invalid
      @sort_string = self.class::SORT_FIELDS[self.class::DEFAULT_SORT_FIELD].to_s + ' ' + self.class::DEFAULT_SORT_ORDER.to_s.upcase
      @external_sort_string = ((self.class::DEFAULT_SORT_ORDER == :desc) ? '-' : '') + self.class::DEFAULT_SORT_FIELD.to_s
    end
  end

  def set_initial_pagination_variables
    page_param = params[:page] || {}
    page_number = (page_param['number'] || 1).to_i

    @page = {
      number: page_number,
      size: [[(page_param['size'] || APP_CONFIG['page_size_small']).to_i, MAX_PAGE_SIZE].min, MIN_PAGE_SIZE].max,
      prev: (page_number > 1) ? (page_number - 1) : nil
    }
  end
  
  def set_calculated_pagination_variables(query_criteria)
    query_count = query_criteria.count
    
    if query_count > (@page[:size] * @page[:number])
      @page[:next] = @page[:number] + 1
    else
      @page[:next] = nil
    end

    @page[:last] = (query_count / (@page[:size].to_f)).ceil
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