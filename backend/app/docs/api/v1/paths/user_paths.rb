class Api::V1::Paths::UserPaths
  include Swagger::Blocks
   
  swagger_path '/users/{key}' do
    
    #=== GET USER ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

      # Basic Info
      define_basic_info :user, :get, 'Get user by id, username or email'

      # Parameters
      parameter :user_key

      # Responses
      define_success_response :user, 200, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

  end
  
  swagger_path '/users/{user_key}/groups' do
    
    #=== USER GROUPS INDEX ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::PaginatedList

      # Basic Info
      define_basic_info :group, 'Get list of groups selected user belongs to', :user
      
      # Parameters
      parameter :user_user_key
      parameter :group_membership_status
      parameter :group_sort
      parameter :page_number
      parameter :page_size

      # Responses
      define_success_response :group, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

  end
  
  swagger_path '/users/{user_key}/portfolios' do
    
    #=== USER PORTFOLIOS INDEX ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::PaginatedList

      # Basic Info
      define_basic_info :portfolio, 'Get list of portfolios for selected user', :user
      
      # Parameters
      parameter :user_user_key
      parameter :portfolio_status
      parameter :portfolio_sort
      parameter :page_number
      parameter :page_size

      # Responses
      define_success_response :portfolio, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

  end
  
  swagger_path '/users/{user_key}/app_user_memberships' do

    #=== USER APP USER MEMBERSHIPS INDEX ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::PaginatedList

      # Basic Info
      define_basic_info :app_user_membership, 'Get list of app memberships for selected user', :user
      
      # Parameters
      parameter :user_user_key
      parameter :app_user_membership_status
      parameter :app_user_membership_type
      parameter :app_user_membership_app_approval_status
      parameter :app_user_membership_user_approval_status
      parameter :app_user_membership_sort
      parameter :page_number
      parameter :page_size

      # Responses
      define_success_response :app_user_membership, include: [:relationships]
      define_unauthorized_response
    end

    #=== CREATE USER APP USER MEMBERSHIP ===#

    operation :post do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

      # Basic Info
      define_basic_info :app_user_membership, :create, 'Create new app membership for selected user', :user
      
      # Parameters
      parameter :user_user_key
      define_post_parameters :app_user_membership

      # Responses
      define_success_response :app_user_membership, 201, include: [:relationships]
      define_field_error_response
      define_unauthorized_response
    end

  end

  swagger_path '/users/{user_key}/app_user_memberships/{key}' do

    #=== GET USER APP USER MEMBERSHIP ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

      # Basic Info
      define_basic_info :app_user_membership, :get, 'Get membership by app key for specified user', :user
      
      # Parameters
      parameter :user_user_key
      parameter :app_key

      # Responses
      define_success_response :badge, 200, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

  end

  #=== INTERNAL-ONLY USER PATHS ===#

  class Internal < Api::V1::Paths::UserPaths

    swagger_path '/users/{user_key}/authentication_tokens' do

      #=== AUTHENTICATION TOKEN INDEX ===#

      operation :get do
        extend Api::V1::Helpers::OperationFormat::Base
        extend Api::V1::Helpers::OperationFormat::PaginatedList

        # Basic Info
        define_basic_info :authentication_token, 'Get list of authentication_tokens for selected user', :user
        
        # Parameters
        parameter :user_user_key
        parameter :authentication_token_sort
        parameter :page_number
        parameter :page_size

        # Responses
        define_success_response :authentication_token, include: [:relationships]
        define_unauthorized_response
      end

      #=== CREATE AUTHENTICATION TOKEN ===#

      operation :post do
        extend Api::V1::Helpers::OperationFormat::Base
        extend Api::V1::Helpers::OperationFormat::RecordItem

        # Basic Info
        define_basic_info :authentication_token, :create, 'Create new authentication token for selected user', :user
        
        # Parameters
        parameter :user_user_key
        define_post_parameters :authentication_token

        # Responses
        define_success_response :authentication_token, 201, include: [:relationships]
        define_field_error_response
        define_unauthorized_response
      end
    
    end
   
  end

end