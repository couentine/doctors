class Api::V1::DocsController < ActionController::Base
  include Swagger::Blocks

  #=== CONSTANTS ===#

  SWAGGERED_CLASSES_EXTERNAL = [
    Api::V1::BadgePaths,
    Api::V1::BadgeSchemas,
    self
  ].freeze

  SWAGGERED_CLASSES_INTERNAL = [
    Api::V1::BadgePaths,
    Api::V1::BadgeSchemas,
    self
  ].freeze

  #=== ROOT METADATA ===#

  swagger_root do
    key :swagger, '2.0'

    info do
      key :version, '1.0'
      key :title, 'Badge List API'
      key :description, 'The public API for the Badge List platform'
      key :termsOfService, 'https://www.badgelist.com/terms-of-service'
      contact do
        key :name, 'Badge List Support Team'
        key :email, 'team@badgelist.com'
      end
    end
    
    tag do
      key :name, 'paginatedListFormat'
      key :description, 'Operations which accept page parameter and respond with an items array and nextPage field.'
    end
    tag do
      key :name, 'recordItemFormat'
      key :description, 'Operations which allow retrieving and modifying single record items. These support a subset of the standard ' \
        'restful actions and potentially additional custom actions.'
    end
    tag do
      key :name, 'groupModel'
      key :description, 'A group represents an organization of some sort. Every badge in Badge List belongs to one specific group. ' \
        'Groups have admin and member users and can contain group tags.'
    end
    tag do
      key :name, 'badgeModel'
      key :description, 'Badges are micro-credentials which represent specific learning skills and achievements. When a user joins a ' \
        'badge they become a ‘badge learner’ and a ‘badge portfolio’ is created for them. Once the badge has been awarded they are ' \
        'referred to as a ‘badge expert’.'
    end

    key :host, 'www.badgelist.com'
    key :basePath, '/api/v1'
    key :schemes, ['https']
    key :consumes, ['application/json']
    key :produces, ['application/json']
  end

  #=== ACTIONS ===#

  # This is the externally-facing API
  def external
    render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES_EXTERNAL)
  end
  
  # This is the internal API which includes everything in the external API, plus some additional actions
  # which are only able to be used from the Badge List site itself.
  def internal
    render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES_INTERNAL)
  end

end