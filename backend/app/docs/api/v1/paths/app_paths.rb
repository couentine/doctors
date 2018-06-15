class Api::V1::Paths::AppPaths
  include Swagger::Blocks

  swagger_path '/apps/{key}' do
    
    #=== GET APP ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

      # Basic Info
      define_basic_info :app, :get, 'Get app by id or slug'

      # Parameters
      parameter :app_key

      # Responses
      define_success_response :app, 200, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

    #=== UPDATE APP ===#

    operation :put do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

      # Basic Info
      define_basic_info :app, :update
      define_put_parameters :app
      
      # Parameters
      parameter :app_key

      # Responses
      define_success_response :app, 200, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

    #=== DELETE APP ===#

    operation :delete do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

      # Basic Info
      define_basic_info :app, :delete
      
      # Parameters
      parameter :app_key

      # Responses
      define_successfully_deleted_response :app
      define_unauthorized_response
      define_not_found_response
    end

  end

  swagger_path '/apps' do

    #=== CREATE APP ===#

    operation :post do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

      # Basic Info
      define_basic_info :app, :create
      
      # Parameters
      define_post_parameters :app

      # Responses
      define_success_response :app, 201, include: [:relationships]
      define_field_error_response
      define_unauthorized_response
    end

  end

  swagger_path '/apps/{app_key}/app_user_memberships' do

    #=== APP APP USER MEMBERSHIPS INDEX ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::PaginatedList

      # Basic Info
      define_basic_info :app_user_membership, 'Get list of user memberships for selected app', :app
      
      # Parameters
      parameter :app_app_key
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

    #=== CREATE APP APP USER MEMBERSHIP ===#

    operation :post do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

      # Basic Info
      define_basic_info :app_user_membership, :create, 'Create new user membership for selected app', :app
      
      # Parameters
      parameter :app_app_key
      define_post_parameters :app_user_membership

      # Responses
      define_success_response :app_user_membership, 201, include: [:relationships]
      define_field_error_response
      define_unauthorized_response
    end

  end

  swagger_path '/apps/{app_key}/app_group_memberships' do

    #=== APP APP GROUP MEMBERSHIPS INDEX ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::PaginatedList

      # Basic Info
      define_basic_info :app_group_membership, 'Get list of group memberships for selected app', :app
      
      # Parameters
      parameter :app_app_key
      parameter :app_group_membership_status
      parameter :app_group_membership_app_approval_status
      parameter :app_group_membership_group_approval_status
      parameter :app_group_membership_sort
      parameter :page_number
      parameter :page_size

      # Responses
      define_success_response :app_group_membership, include: [:relationships]
      define_unauthorized_response
    end

    #=== CREATE APP APP GROUP MEMBERSHIP ===#

    operation :post do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

      # Basic Info
      define_basic_info :app_group_membership, :create, 'Create new group membership for selected app', :app
      
      # Parameters
      parameter :app_app_key
      define_post_parameters :app_group_membership

      # Responses
      define_success_response :app_group_membership, 201, include: [:relationships]
      define_field_error_response
      define_unauthorized_response
    end

  end

end