class Docs::Api::V1::GroupApiDocsController < ActionController::Base
  include Swagger::Blocks

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
      api_noun: :group,
      title: 'Badge List Group API',
      logo_url: 'https://s3.amazonaws.com/badgelist/images/badge-list-icon-blue.png',
      background_color: COLORS['light_blue'][600],
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
    render layout: 'layouts/api_docs'
  end

  def show_json
    render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
  end

end