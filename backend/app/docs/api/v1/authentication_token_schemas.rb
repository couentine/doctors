class Api::V1::AuthenticationTokenSchemas
  include Swagger::Blocks

  #=== AUTHENTICATION TOKEN ATTRIBUTES ===#

  swagger_schema :AuthenticationTokenOutputAttributes do
    extend Api::V1::SharedSchemas::CommonDocumentFields

    key :type, :object
    
    property :value do
      key :type, :string
      key :description, 'The authentication token value which should be passed to the api'
    end
    
    property :permission_sets do
      key :type, :array
      key :description, 'List of permissions which have been granted for this authentication token'

      items do
        key :type, :string
        key :enum, ApplicationPolicy::PERMISSION_SETS.keys
      end
    end

    property :request_count do
      key :type, :integer
      key :description, 'The total number of API requests which have been authenticated with this token'
    end
    property :last_used_at do
      key :type, :string
      key :format, 'date-time'
      key :description, 'Timestamp of the last request authenticated with this token'
    end
    property :ip_address do
      key :type, :string
      key :description, 'IP address of the last request authenticated with this token'
    end
    property :user_agent do
      key :type, :string
      key :description, 'HTTP user agent value of the last request authenticated with this token'
    end
  end

  #=== AUTHENTICATION TOKEN OUTPUT ATTRIBUTES ===#

  swagger_schema :AuthenticationTokenInputAttributes do
    key :type, :object

    property :user_id do
      key :type, :string
      key :format, :id
      key :description, 'The id of the user record to which this token should authenticate. Must be either the current user or a group ' \
        'user for a group which the current user is an admin of.'
    end
    property :permission_sets do
      key :type, :array
      key :description, 'List of permissions which have been granted for this authentication token'

      items do
        key :type, :string
        key :enum, ApplicationPolicy::PERMISSION_SETS.keys
      end
    end
  end

  #=== AUTHENTICATION TOKEN META ===#
  
  swagger_schema :AuthenticationTokenMeta do
    key :type, :object

    property :current_user do
      key :type, :object
      
      property :can_see_record do
        key :type, :boolean
        key :description, 'True if the current user is able to see the authentication token'
      end
      property :can_delete_record do
        key :type, :boolean
        key :description, 'True if the current user is able to delete the authentication token'
      end
    end
  end

  #=== AUTHENTICATION TOKEN RELATIONSHIPS ===#

  swagger_schema :AuthenticationTokenRelationships do
    extend Api::V1::SharedSchemas::RelationshipsList

    key :type, :object

    define_relationship_property :user, 'The authenticating user account to which the token is linked'
    define_relationship_property :creator, 'The user account which created the token'
  end

end