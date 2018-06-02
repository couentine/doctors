class Docs::Api::V1::InternalApiDocsController < ActionController::Base
  include Swagger::Blocks
  include ApplicationHelper

  #=== CONSTANTS ===#

  SWAGGERED_CLASSES = [
    
    ::Api::V1::Paths::AppGroupMembershipPaths,
    ::Api::V1::Paths::AppPaths,
    ::Api::V1::Paths::AppUserMembershipPaths,
    ::Api::V1::Paths::AuthenticationTokenPaths,
    ::Api::V1::Paths::BadgePaths,
    ::Api::V1::Paths::GroupPaths,
    ::Api::V1::Paths::PollerPaths,
    ::Api::V1::Paths::PortfolioPaths,
    ::Api::V1::Paths::UserPaths,
    ::Api::V1::Paths::UserPaths::Internal,

    ::Api::V1::Schemas::AppGroupMembershipSchemas,
    ::Api::V1::Schemas::AppSchemas,
    ::Api::V1::Schemas::AppUserMembershipSchemas,
    ::Api::V1::Schemas::AuthenticationTokenSchemas,
    ::Api::V1::Schemas::BadgeSchemas,
    ::Api::V1::Schemas::EndorsementSchemas,
    ::Api::V1::Schemas::ErrorSchemas,
    ::Api::V1::Schemas::GroupSchemas,
    ::Api::V1::Schemas::PollerSchemas,
    ::Api::V1::Schemas::PortfolioSchemas,
    ::Api::V1::Schemas::SharedSchemas,
    ::Api::V1::Schemas::UserSchemas,

    self
  ].freeze

  #=== ROOT METADATA ===#

  swagger_root do
    extend ::Api::V1::Helpers::RootHelpers

    key :swagger, '2.0'

    #=== BASE API INFO / MARKDOWN DESCRIPTION ===#

    define_info(
      title: 'Badge List Internal API',
      logo_url: 'https://s3.amazonaws.com/badgelist/images/badge-list-icon-blue-grey.png',
      background_color: COLORS['blue_grey'][600],
      description: "This is the documentation for the **Badge List Internal** API.\n" \
        "\n" \
        "The Badge List Internal API is used by the Badge List website itself. It is only able to be accessed from pages rendered by " \
        "the Badge List server and via requests authenticated via the normal user login flow.\n" \
        "\n" \
        "For the publicly-available API refer to the [Badge List API Docs](../v1)." \
        "\n" \
        "## Usage Restrictions ##\n" \
        "Permission to access to the Badge List Internal API by developers outside of Knowledgestreem must be granted in writing " \
        "and manually enabled by our development team.\n" \
        "\n" \
        "The Badge List Internal API includes security safeguards to ensure compliance " \
        "with this policy. Third party developers are encouraged to utilize the Internal API's documentation as a learning tool to " \
        "better understand the functionality of the application " \
        "(subject to our [Terms of Service](https://www.badgelist.com/terms-of-service)), but any attempts to circumvent " \
        "our security safeguards will be considered violations of our [Terms of Service](https://www.badgelist.com/terms-of-service) " \
        "and may result in legal action."
    )
    
    #=== PARAMETERS ===#

    define_shared_parameters :user, :group, :badge, :endorsement, :portfolio, :app, :app_user_membership, :app_group_membership, :poller, 
      :authentication_token

    #=== MODEL TAGS ===#

    define_model_tags :user, :group, :badge, :endorsement, :portfolio, :app, :app_user_membership, :app_group_membership, :poller, 
      :authentication_token

    #=== OPERATION FORMAT TAGS ===#
    
    define_operation_format_tags

    #=== TAG GROUPS (USED BY REDOC) ===#
    
    define_tag_groups :user, :group, :badge, :endorsement, :portfolio, :app, :app_user_membership, :app_group_membership, :poller, 
      :authentication_token

    #=== SECURITY ===#

    define_security :csrf_token

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