class Api::V1::GroupPaths
  include Swagger::Blocks

  swagger_path '/groups/{key}' do
    
    #=== GET GROUP ===#

    operation :get do
      extend Api::V1::SharedOperationFormats::Base
      extend Api::V1::SharedOperationFormats::RecordItem

      # Basic Info
      define_basic_info :group, :get, 'Get group by id or slug'

      # Parameters
      parameter do
        key :name, :key
        key :in, :path
        key :description, "You can query group records using any of the following keys:\n" \
          "- Record id\n" \
          "- Group slug (case insensitive)"
        key :required, true
        key :type, :string
      end

      # Responses
      define_success_response :group, 200, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

  end

  swagger_path '/groups' do

    #=== GROUP INDEX ===#

    operation :get do
      extend Api::V1::SharedOperationFormats::Base
      extend Api::V1::SharedOperationFormats::PaginatedList

      # Basic Info
      define_basic_info :group, 'Get list of groups current user belongs to'
      
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
      define_success_response :group, include: [:relationships]
      define_unauthorized_response
    end

  end
  
  swagger_path '/groups/{key}/badges' do
    
    #=== GROUP BADGE INDEX ===#

    operation :get do
      extend Api::V1::SharedOperationFormats::Base
      extend Api::V1::SharedOperationFormats::PaginatedList

      # Basic Info
      define_basic_info :badge, 'Get list of badges in specified group', :group
      
      # Parameters
      parameter do
        key :name, :key
        key :in, :path
        key :description, "You can query group records using any of the following keys:\n" \
          "- Record id\n" \
          "- Group slug (case insensitive)"
        key :required, true
        key :type, :string
      end
      define_index_parameters :badge

      # Responses
      define_success_response :badge, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

  end
  
  swagger_path '/groups/{key}/users' do
    
    #=== GROUP USER INDEX ===#

    operation :get do
      extend Api::V1::SharedOperationFormats::Base
      extend Api::V1::SharedOperationFormats::PaginatedList

      # Basic Info
      define_basic_info :user, 'Get list of users in specified group', :group
      
      # Parameters
      parameter do
        key :name, :key
        key :in, :path
        key :description, "You can query group records using any of the following keys:\n" \
          "- Record id\n" \
          "- Group slug (case insensitive)"
        key :required, true
        key :type, :string
      end
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
      define_success_response :user, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

  end

end