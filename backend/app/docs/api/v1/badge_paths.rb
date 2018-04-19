class Api::V1::BadgePaths
  include Swagger::Blocks

  swagger_path '/badges/{id}' do
    
    #=== GET BADGE ===#

    operation :get do
      extend Api::V1::SharedOperationFormats::Base
      extend Api::V1::SharedOperationFormats::RecordItem

      # Basic Info
      define_basic_info :badge, :get

      # Parameters
      parameter do
        key :name, :id
        key :format, :id
        key :in, :path
        key :description, 'The id of the badge record'
        key :required, true
        key :type, :string
      end

      # Responses
      define_success_response :badge, 200, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

  end

  swagger_path '/badges' do

    #=== BADGE INDEX ===#

    operation :get do
      extend Api::V1::SharedOperationFormats::Base
      extend Api::V1::SharedOperationFormats::PaginatedList

      # Basic Info
      define_basic_info :badge, 'Get list of badges current user has joined'
      
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
      define_index_parameters :badge

      # Responses
      define_success_response :badge, include: [:relationships]
      define_unauthorized_response
    end

  end

  swagger_path '/badges/{id}/portfolios' do
    
    #=== BADGE PORTFOLIO INDEX ===#

    operation :get do
      extend Api::V1::SharedOperationFormats::Base
      extend Api::V1::SharedOperationFormats::PaginatedList

      # Basic Info
      define_basic_info :portfolio, 'Get list of portfolios for selected badge', :badge
      
      # Parameters
      parameter do
        key :name, :id
        key :format, :id
        key :in, :path
        key :description, 'The id of the badge record'
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

  swagger_path '/badges/{badge_id}/portfolios/{user_key}' do

    #=== GET PORTFOLIO ===#

    operation :get do
      extend Api::V1::SharedOperationFormats::Base
      extend Api::V1::SharedOperationFormats::RecordItem

      # Basic Info
      define_basic_info :portfolio, :get, 'Get portfolio by badge id and user id/username/email', :badge
      key :description, 'This operation allows you to quickly check if a known person holds a specific badge. ' \
        'You must provide the badge id along with a user\'s username, id or email address. ' \
        'If the specified user does not exist in the system or if there is no badge portfolio for them yet you will get a 404 response.'

      # Parameters
      parameter do
        key :name, :badge_id
        key :format, :id
        key :in, :path
        key :description, 'The id of the badge record'
        key :required, true
        key :type, :string
      end
      parameter do
        key :name, :user_key
        key :in, :path
        key :description, "You can query user records using any of the following keys:\n" \
          "- Record id\n" \
          "- Username (case insensitive)\n" \
          "- Email address (case insensitive)"
        key :required, true
        key :type, :string
      end

      # Responses
      define_success_response :portfolio, 200, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

  end

end