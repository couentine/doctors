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
      parameter :authentication_token_id

      # Responses
      define_success_response :authentication_token, 200, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

    #=== UPDATE AUTHENTICATION TOKEN ===#

    operation :put do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

      # Basic Info
      define_basic_info :authentication_token, :update
      
      # Parameters
      parameter :authentication_token_id

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
      parameter :authentication_token_id

      # Responses
      define_successfully_deleted_response :authentication_token
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
      parameter :authentication_token_sort
      parameter :page_number
      parameter :page_size

      # Responses
      define_success_response :authentication_token, include: [:relationships]
      define_unauthorized_response
    end

  end

end