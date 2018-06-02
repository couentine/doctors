class Api::V1::Schemas::AuthenticationTokenSchemas < Api::V1::Schemas::ApiSchema

  model :authentication_token

  #=== FIELDS ===#

  field :user_id, [:string, :id],
    description: 'The id of the authenticating user account to which the token is linked'

  field :name, :string, 
    description: 'User-specified name which helps to differentiate tokens',
    max_from: :name,
    example: 'LMS Integration'

  field :value, :string,
    description: 'The authentication token value which should be passed to the api'

  field :permissions, :array,
    description: 'List of permissions which have been granted for this authentication token',
    enum: ApplicationPolicy::API_PERMISSIONS.keys

  field :request_count, :integer,
    description: 'The total number of API requests which have been authenticated with this token'

  field :last_used_at, [:string, :'date-time'],
    description: 'Timestamp of the last request authenticated with this token'

  field :ip_address, :string,
    description: 'IP address of the last request authenticated with this token'

  field :user_agent, :string,
    description: 'HTTP user agent value of the last request authenticated with this token'
  
  field :creator_id, [:string, :id],
    description: "The user id of the token's creator"

  #=== SCHEMAS ===#

  attributes_schema :output
  
  attributes_schema :input
  
  meta_schema :creator

  relationship_schemas \
    user: 'The authenticating user account to which the token is linked',
    creator: 'The user account which created the token'

end