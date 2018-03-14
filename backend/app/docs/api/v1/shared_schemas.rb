module Api::V1::SharedSchemas

  #=== COMMON DOCUMENT FIELDS ===#

  module CommonDocumentFields
    def self.extended(base)
      base.property :slug do
        key :type, :string
        key :format, :slug
        key :description, 'The url-safe string used to represent this record in urls and other external-facing contexts, ' \
          'all lowercase'
      end
      base.property :slug_with_caps do
        key :type, :string
        key :format, :slug
        key :description, 'The url-safe string used to represent this record in urls and other external-facing contexts, ' \
          'includes capitalization as specified by the creating user'
      end
      base.property :created_at do
        key :type, :string
        key :format, 'date-time'
        key :description, 'Timestamp when the record was initially created'
      end
      base.property :updated_at do
        key :type, :string
        key :format, 'date-time'
        key :description, 'Timestamp when the record was most recently updated'
      end
    end
  end

  #=== RELATIONSIPS LIST ===#

  module RelationshipsList
    # Example Usage:
    # - relationship_name = :group
    # - relationship_description = 'The parent group to which the badge belongs'
    def define_relationship_property(relationship_name, relationship_description)
      property relationship_name do
        key :type, :object
        key :description, relationship_description
        
        property :links do
          key :type, :object
          
          property :self do
            key :type, :string
            key :format, :url
          end
        end
      end
    end
  end

end