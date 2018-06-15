class Api::V1::Paths::GroupPaths
  include Swagger::Blocks

  swagger_path '/groups/{key}' do
    
    #=== GET GROUP ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

      # Basic Info
      define_basic_info :group, :get, 'Get group by id or slug'

      # Parameters
      parameter :group_key

      # Responses
      define_success_response :group, 200, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

  end

  swagger_path '/groups' do

    #=== GROUP INDEX ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::PaginatedList

      # Basic Info
      define_basic_info :group, 'Get list of groups current user belongs to', nil, 'current_user:read'
      
      # Parameters
      parameter :group_membership_status
      parameter :group_sort
      parameter :page_number
      parameter :page_size

      # Responses
      define_success_response :group, include: [:relationships]
      define_unauthorized_response
    end

  end
  
  swagger_path '/groups/{group_key}/badges' do
    
    #=== GROUP BADGES INDEX ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::PaginatedList

      # Basic Info
      define_basic_info :badge, 'Get list of badges in specified group', :group
      
      # Parameters
      parameter :group_group_key
      parameter :badge_sort
      parameter :page_number
      parameter :page_size

      # Responses
      define_success_response :badge, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

  end

  swagger_path '/groups/{group_key}/badges/{key}' do
    
    #=== GET GROUP BADGE ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

      # Basic Info
      define_basic_info :badge, :get, 'Get badge by key within specified group', :group
      
      # Parameters
      parameter :group_group_key
      parameter :badge_key

      # Responses
      define_success_response :badge, 200, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

  end
  
  swagger_path '/groups/{group_key}/users' do
    
    #=== GROUP USERS INDEX ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::PaginatedList

      # Basic Info
      define_basic_info :user, 'Get list of users in specified group', :group
      
      # Parameters
      parameter :group_group_key
      parameter :user_group_membership_type
      parameter :user_sort
      parameter :page_number
      parameter :page_size

      # Responses
      define_success_response :user, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

  end

  swagger_path '/groups/{group_key}/app_group_memberships' do

    #=== GROUP APP GROUP MEMBERSHIPS INDEX ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::PaginatedList

      # Basic Info
      define_basic_info :app_group_membership, 'Get list of app memberships for selected group', :group
      
      # Parameters
      parameter :group_group_key
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

    #=== CREATE GROUP APP GROUP MEMBERSHIP ===#

    operation :post do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

      # Basic Info
      define_basic_info :app_group_membership, :create, 'Create new app membership for selected group', :group
      
      # Parameters
      parameter :group_group_key
      define_post_parameters :app_group_membership

      # Responses
      define_success_response :app_group_membership, 201, include: [:relationships]
      define_field_error_response
      define_unauthorized_response
    end

  end

end