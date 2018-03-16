class Api::V1::BadgePaths
  include Swagger::Blocks

  swagger_path '/badges/{id}' do
    
    #=== GET BADGE ===#

    operation :get do
      extend Api::V1::SharedOperationFormats::RecordItem

      # Basic Info
      define_basic_info :badge

      # Parameters
      define_standard_parameters :badge, :group

      # Responses
      define_success_response :badge, include: [:relationships]
    end

  end

  swagger_path '/badges' do

    #=== BADGE INDEX ===#

    operation :get do
      extend Api::V1::SharedOperationFormats::PaginatedList

      # Basic Info
      define_basic_info :badge, 'Gets a list of all badges the current user has joined'
      
      # Parameters
      parameter do
        key :name, 'filter[status]'
        key :in, :query
        key :description, 'Includes only badges that current user has earned (`holder`) or not earned (`seeker`)'
        key :required, false
        key :type, :string
        key :enum, [:all, :seeker, :holder]
        key :default, :all
      end
      define_standard_parameters :badge

      # Responses
      define_success_response :badge, include: [:relationships]
    end

  end

end