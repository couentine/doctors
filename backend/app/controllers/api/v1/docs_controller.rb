class Api::V1::DocsController < ActionController::Base
  include Swagger::Blocks

  #=== CONSTANTS ===#

  SWAGGERED_CLASSES_EXTERNAL = [
    Api::V1::Paths::UserPaths,
    Api::V1::Schemas::UserSchemas,
    Api::V1::Paths::GroupPaths,
    Api::V1::Schemas::GroupSchemas,
    Api::V1::Paths::BadgePaths,
    Api::V1::Schemas::BadgeSchemas,
    Api::V1::Schemas::EndorsementSchemas,
    Api::V1::Paths::PollerPaths,
    Api::V1::Schemas::PollerSchemas,
    Api::V1::Paths::PortfolioPaths,
    Api::V1::Schemas::PortfolioSchemas,
    Api::V1::Schemas::SharedSchemas,
    Api::V1::Schemas::ErrorSchemas,
    self
  ].freeze

  SWAGGERED_CLASSES_INTERNAL = [
    Api::V1::Paths::UserPaths,
    Api::V1::Schemas::UserSchemas,
    Api::V1::Paths::GroupPaths,
    Api::V1::Schemas::GroupSchemas,
    Api::V1::Paths::BadgePaths,
    Api::V1::Schemas::BadgeSchemas,
    Api::V1::Schemas::EndorsementSchemas,
    Api::V1::Paths::PollerPaths,
    Api::V1::Schemas::PollerSchemas,
    Api::V1::Paths::PortfolioPaths,
    Api::V1::Schemas::PortfolioSchemas,
    Api::V1::Schemas::SharedSchemas,
    Api::V1::Schemas::ErrorSchemas,
    Api::V1::Paths::AuthenticationTokenPaths, # web UI only
    Api::V1::Schemas::AuthenticationTokenSchemas, # web UI only
    self
  ].freeze

  #=== ROOT METADATA ===#

  swagger_root do
    key :swagger, '2.0'

    #=== BASE API INFO / MARKDOWN DESCRIPTION ===#

    info do
      key :version, '1.0'
      key :title, 'Badge List API'
      key :'x-logo', {
        url: 'https://s3.amazonaws.com/badgelist/images/badge-list-icon.png',
        backgroundColor: '#FB8C00'
      }
      key :description, "This is the documentation for the Badge List public API. Badge List is a platform for creating and awarding " \
        "evidence-based digital badges which represent important skills and achievements. The API is completely free, but certain " \
        "operations are restricted based on the user and group context of the request.\n\n " \
        \
        "## Introduction ##\n" \
        "The Badge List API is organized around REST and follows v1.0 of the [JSON API specification](http://jsonapi.org/format/). " \
        "The API is documented using v2 of the " \
        "[OpenAPI/Swagger specification](https://swagger.io/docs/specification/2-0/basic-structure/).\n\n" \
        "If you have any questions you can contact us at team@badgelist.com.\n\n" \
        \
        "## Release Notes (May 2018) ##\n" \
        "The Badge List API is currently being actively expanded. No breaking changes will be made to v1, but we are adding new " \
        "features and operations frequently. Work will continue until we achieve full parity with the web UI.\n\n" \
        \
        "## Data Model ##\n" \
        "Here is an overview of the Badge List data model. " \
        "([Downloadable PDF available here](https://s3.amazonaws.com/badgelist/files/bl-api-data-model-v1.pdf).) " \
        "The API is generally organized as a series of RESTful operations with these core objects, " \
        "with a few extra verbs included here and there.\n\n" \
        "![Badge List Data Model](https://s3.amazonaws.com/badgelist/files/bl-api-data-model-v1.png)\n\n"\
        \
        "## API Structure ##\n" \
        "The API utilizes [swagger tags](https://swagger.io/docs/specification/2-0/grouping-operations-with-tags/) " \
        "as a principal organizational tool. This frees consumers of the API to expect standardized " \
        "behavior across the various endpoints. This also makes the API easier to navigate when using " \
        "[third party swager clients](https://swagger.io/open-source-integrations/).\n\n" \
        "Every operation has two tags:\n" \
        "- **A model tag** describes the principal data model entity being transmitted. For example, all operations tagged with " \
        "  `badgeModel` will transmit badge records, will contain the same attributes in their data items and will respond to the " \
        "  same set of filters and sort fields when applicable.\n" \
        "- **An operation format tag** describes the operational structure of the endpoint. For example, all operations tagged with " \
        "  `paginatedListFormat` will respond with sized lists of items, will accept the same pagination- and list-related parameters " \
        "  and will respond with identical metadata.\n\n" \
        \
        "## API Access ## \n" \
        "In order to use the API you will need an authentication token. There are two basic types of tokens:\n"\
        "- **User Tokens** are linked to a single user account. They are authorized to take actions based on the permissions "\
        "  of the linked user. Certain operations are only available via user token.\n"\
        "- **Group Tokens** are linked to a single group. They are authorized with administrative permissions within the group and are " \
        "  generally allowed to do whatever a group administrator user would be able to do. Certain operations are only available via " \
        "  group token.\n\n" \
        "**Note:** To request an API authentication token please email team@badgelist.com. We will release the ability to create your " \
        "own API tokens via the web UI soon.\n\n"
      key :termsOfService, 'https://www.badgelist.com/terms-of-service'
      contact do
        key :name, 'Badge List Support Team'
        key :email, 'team@badgelist.com'
      end
    end
    
    #=== MODEL TAGS ===#

    # NOTE: We'll leave out the `authenticationTokenModel` tag for now since that is a hidden, internal-only tag.
    tag do
      key :name, 'userModel'
      key :'x-displayName', 'Users'
      key :'x-blType', 'model'
      key :description, 'Every authenticated user of the system has a corresponding user record. There are two types of users. ' \
        'Individual users are normal users created or invited through the standard process. Group users (also referred to as ' \
        'group proxy users) are API-only user accounts which are linked to a specific group and operate with admin permissions for ' \
        'their proxied group.'
    end
    tag do
      key :name, 'groupModel'
      key :'x-displayName', 'Groups'
      key :'x-blType', 'model'
      key :description, 'A group represents an organization of some sort (a company, a school, a district, an online community, etc). ' \
        'Every badge in Badge List belongs to one specific group. Groups also have admin users, member users and group tags. ' \
        'There are "free groups" and "paid groups". Paid groups have a specific "subscription plan" which ' \
        'may enable advanced features for badges and other records within the group.'
    end
    tag do
      key :name, 'badgeModel'
      key :'x-displayName', 'Badges'
      key :'x-blType', 'model'
      key :description, 'Badges are digital credentials which represent specific learning skills and achievements. When a user joins a ' \
        'badge they become a "badge seeker" (aka "badge learner") and a "badge portfolio" is created for them. ' \
        'Once the badge has been awarded the user is referred to as a "badge holder" (aka "badge expert").'
    end
    tag do
      key :name, 'endorsementModel'
      key :'x-displayName', 'Endorsements'
      key :'x-blType', 'model'
      key :description, "Endorsements are a mock model within the API. An endorsement is usually a type of feedback on a " \
        "from a badge awarder on a portfolio which results in the badge being awarded. The endorsement API operations make it easier to " \
        "award badges to people who may not yet have created badge portfolios (or who may not even have Badge List user accounts).\n\n" \
        \
        "The endorsement operations enable one-step awarding of a badge by providing an email address as the unique identifier of " \
        "the intended recipient. Note that this method of badge awarding can result in a badge holder portfolio which has no evidence " \
        "other than the endorsement itself. It is therefore recommended to use other techniques which result in the creation of a more " \
        "robust evidence profile.\n\n" \
        \
        "When a badge is awarded via pre-emptive endorsement there are several possible outcomes:\n" \
        "- **New User Invitation:** If the email address does not correspond to an existing Badge List user account, the user will be " \
        "invited to sign up and will be added to the group's list of 'Invited Members'. The badge endorsement will be stored along with " \
        "the new member's group invitation, but it will not be applied until the person creates their user account. This means that " \
        "the new badge holder will not immediately show up in the list of Badge Experts / Holders.\n" \
        "- **New Member:** If the email address corresponds to an existing Badge List user who is not yet a member of the group, " \
        "they will auomatically be added as a group member, an empty badge portfolio will be created for them and the badge will be " \
        "awarded immediately.\n" \
        "- **Existing Seeker:** If the email address corresponds to an existing badge seeker, then the endorsement will be applied to " \
        "the already created portfolio and the badge will be awarded immediately. If the current user has already provided feedback on " \
        "this portfolio it will be *overwritten* with the new feedback.\n" \
        "- **Existing Holder:** If the email address corresponds to an existing badge holder, then the endorsement will be applied to " \
        "the list of endorsements on the existing portfolio. If the current user has already provided feedback on this portfolio it " \
        "will be *overwritten* with the new feedback.\n"
    end
    tag do
      key :name, 'portfolioModel'
      key :'x-displayName', 'Portfolios'
      key :'x-blType', 'model'
      key :description, 'Every time a user joins a badge, a portfolio is created. The portfolio acts as a container for the evidence ' \
        'items which get posted (as entries). The portfolio also has a `status` which keeps track of where the user is in the feedback ' \
        'process.'
    end
    tag do
      key :name, 'pollerModel'
      key :'x-displayName', 'Pollers'
      key :description, "Pollers are used to track the progress of asynchronous actions. They are automatically deleted " \
        "#{Poller::DELETE_AFTER / 60} minutes after the poller completes."
    end

    #=== OPERATION FORMAT TAGS ===#
    
    tag do
      key :name, 'recordItemFormat'
      key :'x-displayName', 'Record Item Format'
      key :'x-blType', 'itemFormat'
      key :'x-traitTag', true
      key :description, "All operations tagged with `recordItemFormat` are built to retrieve and modify single record items.\n\n" \
        \
        "- All record item format operations for a particular model tag will collectively support the four primary REST verbs: " \
          "GET = getRecord / recordIndex, POST = newRecord, PUT = updateRecord, DELETE = deleteRecord. " \
          "Additional custom retrieving actions may be present using the GET verb. " \
          "Additional custom modifying actions may be present using the POST or PUT verbs.\n" \
        "- All outputted records for a particular model tag will contain the same record output attributes. " \
          "All creation and update operations for a particular model tag will accept the same record input attributes."
    end
    tag do
      key :name, 'paginatedListFormat'
      key :'x-displayName', 'Paginated List Format'
      key :'x-blType', 'listFormat'
      key :'x-traitTag', true
      key :description, "All operations tagged with `paginatedListFormat` are built to retrieve paginated lists of record items.\n\n" \
        \
        "- All paginated list format operations utilize the GET verb.\n" \
        "- Paginated list format responses all accept the same `page[...]` parameters.\n" \
        "- Paginated list format responses utilize the `sort` parameter for sorting the returned record items. " \
          "All paginated list format responses for a particular model tag will accept the same set of sort fields. \n" \
        "- Paginated list format responses utilize the `filter[...]` parameters for filtering the returned record items. " \
          "All paginated list format responses for a particular model tag will accept the same set of filter keys."
    end
    tag do
      key :name, 'batchOperationFormat'
      key :'x-displayName', 'Batch Operation Format'
      key :'x-blType', 'listFormat'
      key :'x-traitTag', true
      key :description, "All operations tagged with `batchOperationFormat` are built to accept batches of up to " \
        "#{APP_CONFIG['max_import_list_size']} items, process them in an asynchronous manner and then respond with a corresponding list " \
        "result items indicating the outcome of each operation.\n\n" \
        \
        "- All batch operations utilize the POST verb.\n" \
        "- Batch operations require that the `data` parameter in the body be an array of data objects.\n" \
        "- Batch operations respond with `202 accepted` and a poller record in the response body. The poller record can be used to " \
          "track the progress of the asynchronous job until it is complete.\n" \
        "- When batch operations are complete their results are stored in the `results` field on the poller record. There will be one " \
          "result item for each data item in the request, at the exact same index in the array.\n" \
        "- **Note:** Most batch operations also have a corresponding 'single mode' operation which operates at the same endpoint " \
          "and also via the POST verb, but accepts a `data` parameter in the body which is a single object rather than an array " \
          "and which returns a synchronous result instead of a poller."
    end

    #=== TAG GROUPS (USED BY REDOC) ===#

    key :'x-tagGroups', [
      {
        name: 'Models',
        tags: [:userModel, :groupModel, :badgeModel, :endorsementModel, :portfolioModel, :pollerModel]
      },
      {
        name: 'Operation Formats',
        tags: [:recordItemFormat, :paginatedListFormat, :batchOperationFormat]
      }
    ]

    key :host, (Rails.env.production?) ? 'www.badgelist.com' : ENV['root_domain']
    key :basePath, '/api/v1'
    key :schemes, (Rails.env.production?) ? ['https'] : ['http']
    key :consumes, ['application/json']
    key :produces, ['application/json']

    security_definition :authentication_token do
      key :type, :apiKey
      key :name, :token
      key :description, "You must include your authentication token in every API request.\n\n" \
        "For all types of requests, the token may be put in a `token` query parameter:\n" \
        "```shell\n" \
        "curl -x GET \"https://www.badgelist.com/api/v1/badges?token=271b8c2395421f5205bf709eLLXUHd1lQv4DbaQzWZzCh8OQmXzLVh\"\n" \
        "```\n\n" \
        "For requests with a JSON body you may alternately include the token at the root level of JSON document:\n" \
        "```shell\n" \
        "curl \n" \
        "  -H \"Content-Type: application/json\" \n" \
        "  -X POST https://www.badgelist.com/api/v1/badges \n" \
        "  -d '{\n" \
        "    \"token\": \"271b8c2395421f5205bf709eLLXUHd1lQv4DbaQzWZzCh8OQmXzLVh\",\n" \
        "    \"data\": {\n" \
        "      // ... \n" \
        "    }\n" \
        "  }'\n" \
        "```"
      key :in, :query
    end
    security_definition :csrf_token do
      key :type, :apiKey
      key :name, :'X-CSRF-Token'
      key :description, "Only used by internal API."
      key :in, :header
    end
    security do
      key :authentication_token, []
      key :csrf_token, []
    end
  end

  #=== ACTIONS ===#

  # This is the externally-facing API
  def external
    render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES_EXTERNAL)
  end
  
  # This is the internal API which includes everything in the external API, plus some additional actions
  # which are only able to be used from the Badge List site itself.
  def internal
    root_json = Swagger::Blocks.build_root_json(SWAGGERED_CLASSES_INTERNAL)
    
    # Note: This is a hack for getting the extra model to show up in the internal spec so the documentation works properly
    root_json[:'x-tagGroups'].map! do |item| 
      if item['name'] == 'Models'
        item['tags'] << 'authenticationTokenModel'
      end

      item
    end
    
    render json: root_json
  end

end