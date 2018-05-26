class Docs::Api::V1::ExternalApiDocsController < ActionController::Base
  include Swagger::Blocks
  include ApplicationHelper

  #=== CONSTANTS ===#

  SWAGGERED_CLASSES = [
    ::Api::V1::Paths::UserPaths,
    ::Api::V1::Schemas::UserSchemas,
    ::Api::V1::Paths::GroupPaths,
    ::Api::V1::Schemas::GroupSchemas,
    ::Api::V1::Paths::BadgePaths,
    ::Api::V1::Schemas::BadgeSchemas,
    ::Api::V1::Schemas::EndorsementSchemas,
    ::Api::V1::Paths::PollerPaths,
    ::Api::V1::Schemas::PollerSchemas,
    ::Api::V1::Paths::PortfolioPaths,
    ::Api::V1::Schemas::PortfolioSchemas,
    ::Api::V1::Schemas::SharedSchemas,
    ::Api::V1::Schemas::ErrorSchemas,
    self
  ].freeze

  #=== ROOT METADATA ===#

  swagger_root do
    extend ::Api::V1::Helpers::RootHelpers

    key :swagger, '2.0'

    #=== BASE API INFO / MARKDOWN DESCRIPTION ===#

    define_info(
      title: 'Badge List API',
      logo_url: 'https://s3.amazonaws.com/badgelist/images/badge-list-icon.png',
      background_color: COLORS['orange'][600],
      description: \
        "This is the official documentation for the **Badge List API**. " \
        "\n" \
        "The Badge List APIs is free to use, but certain operations are restricted based on the context of the request. " \
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
        "Badge List offers a limited **Public API**, accessible without an authentication token, which has read-only access " \
        "to some of the objects (outlined in the table below).\n" \
        "\n" \
        "In order to use most parts of the API, however, you will need an authentication token. Each authentication token belongs to a " \
        "specific parent user. All actions taken with a particular token are tied to its parent user identity in the system. The records " \
        "which can be acted upon via the API are limited by the administrative permissions of the parent user.\n" \
        "\n" \
        "The operations which are available during a particular API request are further limited by the permissions which have " \
        "been enabled for the specific token which is used to authenticate the request. The permissions are selected by the user " \
        "who creates the token. The permissions available to be enabled for a particular authentication token are limited based " \
        "on the the **type of user** to which the token belongs.\n"\
        "\n" \
        "### There are Three Types of Users in Badge List ###\n" \
        "- **Individual Users** are 'normal' users. They are created via the signup form, have passwords and email addresses and " \
        "  login to the system via the web UI.\n" \
        "- Every Badge List group has a single **Group User**, which is a *proxy user*, able to act with full administrative permissions "\
        "  but only on records which are children of the group. The group user is automatically created by the system when the group is " \
        "  created. It does not have an email address or a password and is only able to access the system via the API.\n" \
        "- Every Badge List app has a single **App User**, which is a *proxy user*, able to act with full administrative permissions "\
        "  but only on records which are linked to the app. The app user is automatically created by the system when the app is " \
        "  created. It does not have an email address or a password and is only able to access the system via the API.\n" \
        "\n" \
        "### Available Permissions by User Type ###\n" \
        "The table below shows the permissions which are available to be enabled for authentication tokens linked to each type of user " \
        "(keep in mind that the specific permissions for each token are selected by the user who creates the token). " \
        "Refer to the description of each API operation for a list of which permissions are required in order to access it.\n" \
        "\n" \
        "Permission Name | User API? | Group API? | App API? | Public API?\n" \
        "--------------- | --------- | ---------- | -------- | ----------\n" \
        + ( # We filter out the items which are only available to the internal API, then do a simple mapping into a markdown table
          ApplicationPolicy::PERMISSION_SETS.select do |permission_name, options|
            options[:available_to] != [:web_user]
          end.map do |permission_name, options|
            "`#{permission_name}` | " + [:api_user, :api_group, :api_app, :api_visitor].map do |access_type|
              options[:available_to].include?(access_type) ? '&#10004;' : '&nbsp;'
            end.join(' | ')
          end.join("\n")
        ) + "\n" \
        "\n" \
        "**Note:** To request an API authentication token please email team@badgelist.com.\n" \
        "\n" \
        "## Usage Terms ## \n" \
        "\n" \
        "All usage of Badge List APIs is subject to our [Terms of Service](https://www.badgelist.com/terms-of-service) and " \
        "[Privacy Policy](https://www.badgelist.com/privacy-policy). Usage of the API in any form constitutes acceptance of these " \
        "policies. \n"
    )
    
    #=== MODEL TAGS ===#

    define_model_tags :user, :group, :badge, :endorsement, :portfolio, :poller

    #=== OPERATION FORMAT TAGS ===#
    
    define_operation_format_tags

    #=== TAG GROUPS (USED BY REDOC) ===#
    
    define_tag_groups :user, :group, :badge, :endorsement, :portfolio, :poller

    #=== SECURITY ===#

    define_security :authentication_token

  end

  #=== ACTIONS ===#

  def show_html
    set_app_variables
    render layout: 'layouts/api_docs'
  end

  def show_json
    render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
  end

end