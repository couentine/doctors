class Api::V1::BadgeSchemas
  include Swagger::Blocks

  #=== BADGE OUTPUT ATTRIBUTES ===#

  swagger_schema :BadgeOutputAttributes do
    extend Api::V1::SharedSchemas::CommonDocumentFields
    
    property :slug do
      key :type, :string
      key :format, :slug
      key :description, 'The url-safe string used to represent this badge in urls and other external-facing contexts. Case insensitive.'
    end
    property :name do
      key :type, :string
      key :description, 'Display name of the badge'
    end
    property :summary do
      key :type, :string
      key :description, 'Short summary of the badge and what badge holders have done to earn the badge'
    end

    property :feedback_request_count do
      key :type, :integer
      key :format, :int64
      key :description, 'The number of badge portfolios currently requesting feedback'
    end
    property :seeker_count do
      key :type, :integer
      key :format, :int64
      key :description, 'The number of badge portfolios which have not yet been endorsed, also referred to as learner count'
    end
    property :holder_count do
      key :type, :integer
      key :format, :int64
      key :description, 'The number of badge portfolios which have been endorsed, also referred to as expert count'
    end
    property :image_url do
      key :type, :string
      key :format, :url
      key :description, 'URL of the full-sized badge image PNG, 500 pixels by 500 pixels'
    end
    property :image_medium_url do
      key :type, :string
      key :format, :url
      key :description, 'URL of the resized badge image PNG, 200 pixels by 200 pixels'
    end
    property :image_small_url do
      key :type, :string
      key :format, :url
      key :description, 'URL of the resized badge image PNG, 50 pixels by 50 pixels'
    end

  end

  #=== BADGE META ===#
  
  swagger_schema :BadgeMeta do
    property :current_user do
      key :type, :object
      
      property :can_see_record do
        key :type, :boolean
        key :description, 'True if the current user is able to see the full contents of the badge'
      end
      property :can_edit_record do
        key :type, :boolean
        key :description, 'True if the current user is able to edit the badge'
      end
      property :can_award_record do
        key :type, :boolean
        key :description, 'True if the current user is able to award the badge'
      end
      property :is_seeker do
        key :type, :boolean
        key :description, 'True if the current user has joined but not yet earned the badge'
      end
      property :is_holder do
        key :type, :boolean
        key :description, 'True if the current user has earned the badge'
      end
    end
  end

  #=== BADGE RELATIONSHIPS ===#

  swagger_schema :BadgeRelationships do
    extend Api::V1::SharedSchemas::RelationshipsList

    define_relationship_property :group, 'The parent group to which the badge belongs'
  end

end