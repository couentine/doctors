class Api::V1::GroupPaths
  include Swagger::Blocks

  swagger_path '/groups/{id}' do
    
    #=== GET BADGE ===#

    operation :get do
      extend Api::V1::SharedOperationFormats::RecordItem

      # Basic Info
      define_basic_info :group

      # Parameters
      define_standard_parameters :group

      # Responses
      define_success_response :group
    end

  end

  swagger_path '/groups' do

    #=== BADGE INDEX ===#

    operation :get do
      extend Api::V1::SharedOperationFormats::PaginatedList

      # Basic Info
      define_basic_info :group, 'Gets a list of all groups the current user belongs to'
      
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
      define_standard_parameters :group

      # Responses
      define_success_response :group
    end

  end

end