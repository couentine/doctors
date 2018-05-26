class Api::V1::Paths::BadgePaths
  include Swagger::Blocks

  swagger_path '/badges/{id}' do
    
    #=== GET BADGE ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

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
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::PaginatedList

      # Basic Info
      define_basic_info :badge, 'Get list of badges current user has joined', nil, 'current_user:read'
      
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

  swagger_path '/badges/{badge_id}/endorsements' do
    
    #=== CREATE BADGE ENDORSEMENTS ===#

    operation :post do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::BatchOperation

      # Basic Info
      define_basic_info :endorsement, :create, 'Batch award a badge', :badge, ['portfolios:review'],
        "Batch operation for creating up to #{APP_CONFIG['max_import_list_size']} endorsements with a single request. " \
        "single request. Creating an endorsement automatically awards the badge.\n\nIn order to use this operation you must specify the " \
        "badge awardees by email address. They will automatically be added to the group if they are not yet members. They will " \
        "automatically be invited to create Badge List accounts if they are not yet users.\n" \
        "\n"\
        "This operation has two modes:\n" \
        "- **Single Mode** is triggered when you pass a single object as the `data` parameter. Single mode responds with a " \
          "`201 created` code and the single result in the body.\n" \
        "- **Batch Mode** is triggerred when you pass an array as the `data` parameter. Batch mode responds with a `202 accepted` code " \
          "and a poller record in the body. Batch mode runs asynchronously. Once it is completed, you will be able to refer to the " \
          "poller's `results` array to see the result of each item in the request data array. (The `results` array will be null until " \
          "the poller is completed.)\n" \
        "\n" \
        "For details on the possible result types refer to the response examples or the `EndorsementResultAttributes` schema definition."
      
      # Parameters
      parameter do
        key :name, :badge_id
        key :format, :id
        key :in, :path
        key :description, 'The id of the badge record'
        key :required, true
        key :type, :string
      end
      define_post_parameters model: :endorsement, meta_properties: {
        send_emails_to_new_users: { 
          type: :boolean, 
          default: true,
          description: "Controls whether emails are sent to newly invited Badge List users. Note that existing Badge List users will " \
            "always receive email notifications according to their own user preferences.\n\n" \
            \
            "You should generally leave this as true. " \
            "An example of when you might want to set it to false is when you are trying to pre-populate new user accounts with a " \
            "collection of badges and don\'t want to fill their inbox with separate notifications for each one."
        }
      }

      # Responses
      define_success_responses :endorsement
      define_unauthorized_response
      define_not_found_response
    end

  end

  swagger_path '/badges/{badge_id}/portfolios' do
    
    #=== BADGE PORTFOLIO INDEX ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::PaginatedList

      # Basic Info
      define_basic_info :portfolio, 'Get list of portfolios for selected badge', :badge
      
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

  swagger_path '/badges/{badge_id}/portfolios/{key}' do

    #=== GET PORTFOLIO ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

      # Basic Info
      define_basic_info :portfolio, :get, 'Get portfolio by badge id and user id/username/email', :badge,
        'This operation allows you to quickly check if a known person holds a specific badge. ' \
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
      define_success_response :portfolio, 200, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

  end

end