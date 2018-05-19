class Api::V1::Paths::AuthenticationTokenPaths
  include Swagger::Blocks

  swagger_path '/authentication_tokens/{id}' do
    
    #=== GET AUTHENTICATION TOKEN ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

      # Basic Info
      define_basic_info :authentication_token, :get

      # Parameters
      parameter do
        key :name, :id
        key :format, :id
        key :in, :path
        key :description, 'The id of the authentication token record'
        key :required, true
        key :type, :string
      end

      # Responses
      define_success_response :authentication_token, 200, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

    #=== DELETE AUTHENTICATION TOKEN ===#

    operation :delete do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

      # Basic Info
      define_basic_info :authentication_token, :delete
      
      # Parameters
      parameter do
        key :name, :id
        key :format, :id
        key :in, :path
        key :description, 'The id of the authentication token record'
        key :required, true
        key :type, :string
      end

      # Responses
      response 204 do
        key :description, 'The authentication token was successfully deleted'
      end
      define_unauthorized_response
      define_not_found_response
    end

  end

  swagger_path '/authentication_tokens' do

    #=== AUTHENTICATION TOKEN INDEX ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::PaginatedList

      # Basic Info
      define_basic_info :authentication_token, 'Get list of authentication_tokens for current user'
      
      # Parameters
      define_index_parameters :authentication_token

      # Responses
      define_success_response :authentication_token, include: [:relationships]
      define_unauthorized_response
    end

    #=== CREATE AUTHENTICATION TOKEN ===#

    operation :post do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

      # Basic Info
      define_basic_info :authentication_token, :create
      
      # Parameters
      define_post_parameters :authentication_token

      # Responses
      define_success_response :authentication_token, 201, include: [:relationships]
      define_field_error_response
      define_unauthorized_response
    end

  end

end