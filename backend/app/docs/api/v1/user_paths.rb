class Api::V1::UserPaths
  include Swagger::Blocks

  swagger_path '/users/{id}' do
    
    #=== GET USER ===#

    operation :get do
      extend Api::V1::SharedOperationFormats::Base
      extend Api::V1::SharedOperationFormats::RecordItem

      # Basic Info
      define_basic_info :user, :get

      # Parameters
      define_id_parameters :user, nil, :username

      # Responses
      define_success_response :user, 200
      define_unauthorized_response
    end

  end
  
  swagger_path '/users/{id}/groups' do
    
    #=== USER GROUP INDEX ===#

    operation :get do
      extend Api::V1::SharedOperationFormats::Base
      extend Api::V1::SharedOperationFormats::PaginatedList

      # Basic Info
      define_basic_info :group, 'Get list of all groups specified user belongs to', :user
      
      # Parameters
      parameter do
        key :name, 'filter[status]'
        key :in, :query
        key :description, 'Includes only groups where the specified user is a member (`member`) or an admin (`admin`)'
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

end