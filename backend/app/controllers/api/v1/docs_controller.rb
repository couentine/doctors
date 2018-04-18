class Api::V1::DocsController < ActionController::Base
  include Swagger::Blocks

  #=== CONSTANTS ===#

  SWAGGERED_CLASSES_EXTERNAL = [
    Api::V1::UserPaths,
    Api::V1::UserSchemas,
    Api::V1::GroupPaths,
    Api::V1::GroupSchemas,
    Api::V1::BadgePaths,
    Api::V1::BadgeSchemas,
    Api::V1::ErrorSchemas,
    self
  ].freeze

  SWAGGERED_CLASSES_INTERNAL = [
    Api::V1::UserPaths,
    Api::V1::UserSchemas,
    Api::V1::GroupPaths,
    Api::V1::GroupSchemas,
    Api::V1::BadgePaths,
    Api::V1::BadgeSchemas,
    Api::V1::ErrorSchemas,
    Api::V1::AuthenticationTokenPaths, # web UI only
    Api::V1::AuthenticationTokenSchemas, # web UI only
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
        "## Release Notes (April 2018) ##\n" \
        "We have just released v1 of the Badge List API. The initial release only contains endpoints for groups, badges, users " \
        "and portfolios. We are actively working to release new endpoints, so check back here often to get the latest. " \
        "Next up: Group tags. After that we will work through the remaining objects and actions until we achieve " \
        "full parity with the web UI.\n\n" \
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
      key :description, 'Every authenticated user of the system has a corresponding user record. There are two types of users. ' \
        'Individual users are normal users created or invited through the standard process. Group users (also referred to as ' \
        'group proxy users) are API-only user accounts which are linked to a specific group and operate with admin permissions for ' \
        'their proxied group.'
    end
    tag do
      key :name, 'groupModel'
      key :'x-displayName', 'Groups'
      key :description, 'A group represents an organization of some sort (a company, a school, a district, an online community, etc). ' \
        'Every badge in Badge List belongs to one specific group. Groups also have admin users, member users and group tags. ' \
        'There are "free groups" and "paid groups". Paid groups have a specific "subscription plan" which ' \
        'may enable advanced features for badges and other records within the group.'
    end
    tag do
      key :name, 'badgeModel'
      key :'x-displayName', 'Badges'
      key :description, 'Badges are digital credentials which represent specific learning skills and achievements. When a user joins a ' \
        'badge they become a "badge seeker" (aka "badge learner") and a "badge portfolio" is created for them. ' \
        'Once the badge has been awarded the user is referred to as a "badge holder" (aka "badge expert").'
    end

    #=== OPERATION FORMAT TAGS ===#
    
    tag do
      key :name, 'recordItemFormat'
      key :'x-displayName', 'Record Item Format'
      key :'x-traitTag', true
      key :description, "All operations tagged with `recordItemFormat` are built to retrieve and modify single record items.\n\n" \
        "- All record item format operations for a particular model tag will collectively support the four primary REST verbs: " \
        "  GET = getRecord / recordIndex, POST = newRecord, PUT = updateRecord, DELETE = deleteRecord. " \
        "  Additional custom retrieving actions may be present using the GET verb. " \
        "  Additional custom modifying actions may be present using the POST or PUT verbs.\n" \
        "- All outputted records for a particular model tag will contain the same record output attributes. " \
        "  All creation and update operations for a particular model tag will accept the same record input attributes."
    end
    tag do
      key :name, 'paginatedListFormat'
      key :'x-displayName', 'Paginated List Format'
      key :'x-traitTag', true
      key :description, "All operations tagged with `paginatedListFormat` are built to retrieve paginated lists of record items.\n\n" \
        "- All paginated list format operations utilize the GET verb.\n" \
        "- Paginated list format responses all accept the same `page[...]` parameters.\n" \
        "- Paginated list format responses utilize the `sort` parameter for sorting the returned record items. " \
        "  All paginated list format responses for a particular model tag will accept the same set of sort fields. \n" \
        "- Paginated list format responses utilize the `filter[...]` parameters for filtering the returned record items. " \
        "  All paginated list format responses for a particular model tag will accept the same set of filter keys."
    end

    #=== TAG GROUPS (USED BY REDOC) ===#

    key :'x-tagGroups', [
      {
        name: 'Models',
        tags: [:userModel, :groupModel, :badgeModel]
      },
      {
        name: 'Operation Formats',
        tags: [:recordItemFormat, :paginatedListFormat]
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
    security do
      key :authentication_token, []
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