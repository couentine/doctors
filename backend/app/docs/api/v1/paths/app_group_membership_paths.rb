class Api::V1::Paths::AppGroupMembershipPaths
  include Swagger::Blocks

  swagger_path '/app_group_memberships/{id}' do
    
    #=== GET APP USER MEMBERSHIP ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

      # Basic Info
      define_basic_info :app_group_membership, :get

      # Parameters
      parameter :app_group_membership_id

      # Responses
      define_success_response :app_group_membership, 200, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

    #=== UPDATE APP USER MEMBERSHIP ===#

    operation :put do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

      # Basic Info
      define_basic_info :app_group_membership, :update
      
      # Parameters
      parameter :app_group_membership_id
      define_put_parameters :app_group_membership

      # Responses
      define_success_response :app_group_membership, 200, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

    #=== DELETE APP USER MEMBERSHIP ===#

    operation :delete do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

      # Basic Info
      define_basic_info :app_group_membership, :delete
      
      # Parameters
      parameter :app_group_membership_id

      # Responses
      define_successfully_deleted_response :app_group_membership
      define_unauthorized_response
      define_not_found_response
    end

  end

end