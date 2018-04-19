class Api::V1::UserPaths
  include Swagger::Blocks

  swagger_path '/users/{key}' do
    
    #=== GET USER ===#

    operation :get do
      extend Api::V1::SharedOperationFormats::Base
      extend Api::V1::SharedOperationFormats::RecordItem

      # Basic Info
      define_basic_info :user, :get, 'Get user by id, username or email'

      # Parameters
      parameter do
        key :name, :key
        key :in, :path
        key :description, "You can query user records using any of the following keys:\n" \
          "- Record id\n" \
          "- Username (case insensitive)\n" \
          "- Email address (case insensitive)"
        key :required, true
        key :type, :string
      end

      # Responses
      define_success_response :user, 200, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

  end
  
  swagger_path '/users/{key}/groups' do
    
    #=== USER GROUP INDEX ===#

    operation :get do
      extend Api::V1::SharedOperationFormats::Base
      extend Api::V1::SharedOperationFormats::PaginatedList

      # Basic Info
      define_basic_info :group, 'Get list of groups specified user belongs to', :user
      
      # Parameters
      parameter do
        key :name, :key
        key :in, :path
        key :description, "You can query user records using any of the following keys:\n" \
          "- Record id\n" \
          "- Username (case insensitive)\n" \
          "- Email address (case insensitive)"
        key :required, true
        key :type, :string
      end
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
      define_success_response :group, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

  end
  
  swagger_path '/users/{key}/portfolios' do
    
    #=== USER GROUP INDEX ===#

    operation :get do
      extend Api::V1::SharedOperationFormats::Base
      extend Api::V1::SharedOperationFormats::PaginatedList

      # Basic Info
      define_basic_info :portfolio, 'Get list of portfolios for selected user', :user
      
      # Parameters
      parameter do
        key :name, :key
        key :in, :path
        key :description, "You can query user records using any of the following keys:\n" \
          "- Record id\n" \
          "- Username (case insensitive)\n" \
          "- Email address (case insensitive)"
        key :required, true
        key :type, :string
      end
      parameter do
        key :name, 'filter[status]'
        key :in, :query
        key :description, 'Includes only portfolios with the specified status'
        key :required, false
        key :type, :string
        key :enum, [:all, :draft, :requested, :endorsed]
        key :default, :all
      end
      define_index_parameters :portfolio

      # Responses
      define_success_response :portfolio, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

  end

end