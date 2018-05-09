class Api::V1::Schemas::PortfolioSchemas
  include Swagger::Blocks

  #=== PORTFOLIO OUTPUT ATTRIBUTES ===#

  swagger_schema :PortfolioOutputAttributes do
    extend Api::V1::Helpers::SchemaHelpers::CommonDocumentFields

    key :type, :object
    
    property :status do
      key :type, :string
      key :enum, [:draft, :requested, :endorsed]
      key :description, "The status indicates where the portfolio is in the feedback process:\n" \
        "- **draft**: The portfolio is in a working state, the badge is unissued\n" \
        "- **requested**: Feedback has been requested but not yet provided\n" \
        "- **endorsed**: Portfolio has been endorsed, badge is issued, user is a badge holder"
    end

    property :badge_id do
      key :type, :string
      key :format, :id
      key :description, 'The id of the parent badge'
      key :example, '591b91ac95421f51f294b389'
    end
    property :user_id do
      key :type, :string
      key :format, :id
      key :description, 'The id of the parent user'
      key :example, '591b8c2295421f5205bf709e'
    end
    property :user_name do
      key :type, :string
      key :description, 'The name of this user'
      key :example, 'Niel Armstrong'
    end
    property :user_username do
      key :type, :string
      key :description, 'The url-safe string used to represent this user in urls and other external-facing contexts. Case insensitive.'
      key :example, 'NielArmstrong69'
    end

    property :show_on_badge do
      key :type, :boolean
      key :description, 'User visibility control specifying whether this user shows up in the lists of badge seekers / holders'
      key :example, true
    end
    property :show_on_profile do
      key :type, :boolean
      key :description, 'User visibility control specifying whether this badge shows up on the user\'s badge profile'
      key :example, true
    end

    property :date_started do
      key :type, :string
      key :format, :date
      key :description, 'The date which the portfolio was created'
    end
    property :date_requested do
      key :type, :string
      key :format, :date
      key :description, 'The date which feedback was most recently requested'
    end
    property :date_withdrawn do
      key :type, :string
      key :format, :date
      key :description, 'The date which feedback was most recently withdrawn'
    end
    property :date_issued do
      key :type, :string
      key :format, :date
      key :description, 'The date which the badge was awarded'
    end
    property :date_retracted do
      key :type, :string
      key :format, :date
      key :description, 'The date which the badge was retracted'
    end
    property :date_originally_issued do
      key :type, :string
      key :format, :date
      key :description, 'If a badge is retracted, the original issue date is preserved here'
    end

  end

  #=== PORTFOLIO META ===#
  
  swagger_schema :PortfolioMeta do
    key :type, :object

    property :current_user do
      key :type, :object
      
      property :can_see_record do
        key :type, :boolean
        key :description, 'True if the current user is able to see the full contents of the user'
      end
    end
  end

  #=== PORTFOLIO RELATIONSHIPS ===#

  swagger_schema :PortfolioRelationships do
    extend Api::V1::Helpers::SchemaHelpers::RelationshipsList

    key :type, :object

    define_relationship_property :badge, 'The badge to which this portfolio belongs'
    define_relationship_property :user, 'The user to which this portfolio belongs'
  end

end