module Api::V1::Helpers::RootHelpers

  #=== BASE API INFO / MARKDOWN DESCRIPTION ===#

  def define_info(api_noun: :user, title: nil, description: nil, logo_url: 'https://s3.amazonaws.com/badgelist/images/badge-list-icon.png', 
      background_color: COLORS['orange'][600])
    info do
      key :version, '1.0'
      key :title, title
      key :'x-logo', {
        url: logo_url,
        backgroundColor: background_color,
      }
      if description.present?
        key :description, description
      else
        key :description, \
          "This is the documentation for the **Badge List #{api_noun.to_s.capitalize} API**. " \
          "Badge List has two different APIs which operate " \
          "at the same base URL but which include different operations. Which API you are accessing is controlled by the type of " \
          "authentication token provided in the request.\n " \
          "- **The User API** is accessed whenever you provide a User API Token. User API Tokens are always " \
          "  linked to a single Badge List user account. The User API includes access to most of the group-related operations as well as " \
          "  access to the user-related operations. All operations are scoped to the access privileges of the linked user. " \
          "  [User API Documentation lives here](user).\n" \
          "- **The Group API** is accessed whenever you provide a Group API Token. Group API Tokens are always " \
          "  linked to a single Badge List group. The Group API only includes access to group-related operations. " \
          "  All operations are scoped with administrative permissions within the linked group. " \
          "  [Group API Documentation lives here](group).\n" \
          "\n" \
          "All of Badge List's APIs are free to use, but certain operations are restricted based on the context of the request. " \
          "Some operations, for instance, will only work within a group with a particular feature or subscription plan." \
          "\n" \
          "## Introduction ##\n" \
          "The Badge List API is organized around REST and follows v1.0 of the [JSON API specification](http://jsonapi.org/format/). " \
          "The API is documented using v2 of the " \
          "[OpenAPI/Swagger specification](https://swagger.io/docs/specification/2-0/basic-structure/).\n\n" \
          "If you have any questions you can contact us at team@badgelist.com.\n" \
          "\n"\
          "## Release Notes (May 2018) ##\n" \
          "The Badge List API is currently being actively expanded. No breaking changes will be made to v1, but we are adding new " \
          "features and operations frequently. Work will continue until we achieve full parity with the web UI.\n" \
          "\n"\
          "## Data Model ##\n" \
          "Here is an overview of the Badge List data model. " \
          "([Downloadable PDF available here](https://s3.amazonaws.com/badgelist/files/bl-api-data-model-v1.pdf).) " \
          "The API is generally organized as a series of RESTful operations with these core objects, " \
          "with a few extra verbs included here and there.\n\n" \
          "![Badge List Data Model](https://s3.amazonaws.com/badgelist/files/bl-api-data-model-v1.png)\n\n"\
          \
          "## API Structure ##\n" \
          "The Badge List OpenAPI specification utilizes " \
          "[swagger tags](https://swagger.io/docs/specification/2-0/grouping-operations-with-tags/) " \
          "as a principal organizational tool. This frees consumers of the API to expect standardized " \
          "behavior across the various endpoints. This also makes the API easier to navigate when using " \
          "[third party swager clients](https://swagger.io/open-source-integrations/).\n\n" \
          "Every operation has two tags:\n" \
          "- **A model tag** describes the principal data model entity being transmitted. For example, all operations tagged with " \
          "  `badgeModel` will transmit badge records, will contain the same attributes in their data items and will respond to the " \
          "  same set of filters and sort fields when applicable.\n" \
          "- **An operation format tag** describes the operational structure of the endpoint. For example, all operations tagged with " \
          "  `paginatedListFormat` will respond with sized lists of items, will accept the same pagination- and list-related parameters " \
          "  and will respond with identical metadata.\n" \
          "\n"\
          "## API Access ## \n" \
          "In order to use the API you will need an authentication token. There are two basic types of tokens:\n"\
          "- **User API Tokens** are linked to a single user account. They are authorized to take actions based on the permissions "\
          "  of the linked user.\n"\
          "- **Group API Tokens** are linked to a single group. They are authorized with administrative permissions within the group and " \
          "  are generally allowed to do whatever a group administrator user would be able to do. \n" \
          "\n" \
          "**Note:** To request an API authentication token please email team@badgelist.com.\n" \
          "\n" \
          "## Usage Terms ## \n" \
          "\n" \
          "All usage of Badge List APIs is subject to our [Terms of Service](https://www.badgelist.com/terms-of-service) and " \
          "[Privacy Policy](https://www.badgelist.com/privacy-policy). Usage of the API in any form constitutes acceptance of these " \
          "policies. \n"
      end
      key :termsOfService, 'https://www.badgelist.com/terms-of-service'
      contact do
        key :name, 'Badge List Support Team'
        key :email, 'team@badgelist.com'
      end
    end

    key :host, (Rails.env.production?) ? 'www.badgelist.com' : ENV['root_domain']
    key :basePath, '/api/v1'
    key :schemes, (Rails.env.production?) ? ['https'] : ['http']
    key :consumes, ['application/json']
    key :produces, ['application/json']
  end
  
  #=== MODEL TAGS ===#

  def define_model_tags(*models)
    # USER
    if models.include? :user
      tag do
        key :name, 'userModel'
        key :'x-displayName', 'Users'
        key :'x-blType', 'model'
        key :description, 'Every authenticated user of the system has a corresponding user record. There are two types of users. ' \
          'Individual users are normal users created or invited through the standard process. Group users (also referred to as ' \
          'group proxy users) are API-only user accounts which are linked to a specific group and operate with admin permissions for ' \
          'their proxied group.'
      end
    end

    # GROUP
    if models.include? :group
      tag do
        key :name, 'groupModel'
        key :'x-displayName', 'Groups'
        key :'x-blType', 'model'
        key :description, 'A group represents an organization of some sort (a company, a school, a district, an online community, etc). ' \
          'Every badge in Badge List belongs to one specific group. Groups also have admin users, member users and group tags. ' \
          'There are "free groups" and "paid groups". Paid groups have a specific "subscription plan" which ' \
          'may enable advanced features for badges and other records within the group.'
      end
    end
    
    # BADGE
    if models.include? :badge
      tag do
        key :name, 'badgeModel'
        key :'x-displayName', 'Badges'
        key :'x-blType', 'model'
        key :description, 'Badges are digital credentials which represent specific learning skills and achievements. When a user joins a ' \
          'badge they become a "badge seeker" (aka "badge learner") and a "badge portfolio" is created for them. ' \
          'Once the badge has been awarded the user is referred to as a "badge holder" (aka "badge expert").'
      end
    end
    
    # ENDORSEMENT
    if models.include? :endorsement
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
    end
    
    # PORTFOLIO
    if models.include? :portfolio
      tag do
        key :name, 'portfolioModel'
        key :'x-displayName', 'Portfolios'
        key :'x-blType', 'model'
        key :description, 'Every time a user joins a badge, a portfolio is created. The portfolio acts as a container for the evidence ' \
          'items which get posted (as entries). The portfolio also has a `status` which keeps track of where the user is in the feedback ' \
          'process.'
      end
    end
    
    # POLLER
    if models.include? :poller
      tag do
        key :name, 'pollerModel'
        key :'x-displayName', 'Pollers'
        key :description, "Pollers are used to track the progress of asynchronous actions. They are automatically deleted " \
          "#{Poller::DELETE_AFTER / 60} minutes after the poller completes."
      end
    end
    
    # AUTHENTICATION_TOKEN
    if models.include? :authentication_token
      tag do
        key :name, 'authenticationTokenModel'
        key :'x-displayName', 'Authentication Tokens'
        key :description, "FIXME"
      end
    end
  end

  #=== OPERATION FORMAT TAGS ===#
  
  def define_operation_format_tags
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
  end

  #=== TAG GROUPS ===#

  def define_tag_groups(*models)
    key :'x-tagGroups', [
      {
        name: 'Models',
        tags: models.map do |model|
          model.to_s[0, 1].downcase + model.to_s.camelize[1..-1] + 'Model'
        end
      },
      {
        name: 'Operation Formats',
        tags: [:recordItemFormat, :paginatedListFormat, :batchOperationFormat]
      }
    ]
  end

  #=== SECURITY ===#

  def define_security(*security_methods)
    if security_methods.include? :authentication_token
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
    end

    if security_methods.include? :csrf_token
      security_definition :csrf_token do
        key :type, :apiKey
        key :name, :'X-CSRF-Token'
        key :description, "The CRSF token generated by the Badge List server is required on all Internal API requests " \
          "(including get requests)."
        key :in, :header
      end
    end
      
    security do
      security_methods.each do |security_method|
        key security_method, []
      end
    end

  end

end