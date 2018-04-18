class Api::V1::GroupPaths
  include Swagger::Blocks

  swagger_path '/groups/{id}' do
    
    #=== GET GROUP ===#

    operation :get do
      extend Api::V1::SharedOperationFormats::Base
      extend Api::V1::SharedOperationFormats::RecordItem

      # Basic Info
      define_basic_info :group, :get

      # Parameters
      define_id_parameters :group

      # Responses
      define_success_response :group, 200
      define_unauthorized_response
    end

  end

  swagger_path '/groups' do

    #=== GROUP INDEX ===#

    operation :get do
      extend Api::V1::SharedOperationFormats::Base
      extend Api::V1::SharedOperationFormats::PaginatedList

      # Basic Info
      define_basic_info :group, 'Get list of all groups the current user belongs to'
      
      # Parameters
      parameter do
        key :name, 'filter[status]'
        key :in, :query
        key :description, 'Includes only groups where the current user is a member (`member`) or an admin (`admin`)'
        key :required, false
        key :type, :string
        key :enum, [:all, :member, :admin]
        key :default, :all
      end
      define_index_parameters :group

      # Responses
      define_success_response :group
      define_unauthorized_response
    end

  end
  
  swagger_path '/groups/{id}/badges' do
    
    #=== GROUP BADGE INDEX ===#

    operation :get do
      extend Api::V1::SharedOperationFormats::Base
      extend Api::V1::SharedOperationFormats::PaginatedList

      # Basic Info
      define_basic_info :badge, 'Get list of all badges in this group', :group
      
      # Parameters
      parameter do
        key :name, 'filter[visibility]'
        key :in, :query
        key :description, 'Optional filter based on the badge visibility'
        key :required, false
        key :type, :string
        key :enum, [:all, :public, :private, :hidden]
        key :default, :all
      end
      define_index_parameters :badge

      # Responses
      define_success_response :badge
      define_unauthorized_response
    end

  end
  
  swagger_path '/groups/{id}/users' do
    
    #=== GROUP USER INDEX ===#

    operation :get do
      extend Api::V1::SharedOperationFormats::Base
      extend Api::V1::SharedOperationFormats::PaginatedList

      # Basic Info
      define_basic_info :user, 'Get list of all users in this group', :group
      
      # Parameters
      parameter do
        key :name, 'filter[status]'
        key :in, :query
        key :description, 'Includes only members (`member`) or admins (`admin`) or both members and admins (`all`)'
        key :required, false
        key :type, :string
        key :enum, [:all, :member, :admin]
        key :default, :all
      end
      define_index_parameters :user

      # Responses
      define_success_response :user
      define_unauthorized_response
    end

  end

end