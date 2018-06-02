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

    #=== APPS INDEX ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::PaginatedList

      # Basic Info
      define_basic_info :app, "Get list of current user's active apps"
      
      # Parameters
      parameter :app_user_joinability
      parameter :app_group_joinability
      parameter :app_status
      parameter :app_sort
      parameter :page_number
      parameter :page_size

      # Responses
      define_success_response :app, include: [:relationships]
      define_unauthorized_response
    end

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

  swagger_path '/apps/{app_key}/users' do
    
    #=== APP USERS INDEX ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::PaginatedList

      # Basic Info
      define_basic_info :user, 'Get list of active app users', :app
      
      # Parameters
      parameter :app_app_key
      parameter :user_sort
      parameter :page_number
      parameter :page_size

      # Responses
      define_success_response :user, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

  end

  swagger_path '/apps/{app_key}/groups' do
    
    #=== APP GROUPS INDEX ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::PaginatedList

      # Basic Info
      define_basic_info :group, 'Get list of active app groups', :app
      
      # Parameters
      parameter :app_app_key
      parameter :group_sort
      parameter :page_number
      parameter :page_size

      # Responses
      define_success_response :group, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

  end

end