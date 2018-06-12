class Api::V1::Paths::AppUserMembershipPaths
  include Swagger::Blocks

  swagger_path '/app_user_memberships/{id}' do
    
    #=== GET APP USER MEMBERSHIP ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

      # Basic Info
      define_basic_info :app_user_membership, :get

      # Parameters
      parameter :app_user_membership_id

      # Responses
      define_success_response :app_user_membership, 200, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

    #=== UPDATE APP USER MEMBERSHIP ===#

    operation :put do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

      # Basic Info
      define_basic_info :app_user_membership, :update
      
      # Parameters
      parameter :app_user_membership_id
      define_put_parameters :app_user_membership

      # Responses
      define_success_response :app_user_membership, 200, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

    #=== DELETE APP USER MEMBERSHIP ===#

    operation :delete do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

      # Basic Info
      define_basic_info :app_user_membership, :delete
      
      # Parameters
      parameter :app_user_membership_id

      # Responses
      define_successfully_deleted_response :app_user_membership
      define_unauthorized_response
      define_not_found_response
    end

  end

  swagger_path '/app_user_memberships' do

    #=== APP USER MEMBERSHIPS INDEX ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::PaginatedList

      # Basic Info
      define_basic_info :app_user_membership, 'Get list of app user memberships for current user'
      
      # Parameters
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

  end

end