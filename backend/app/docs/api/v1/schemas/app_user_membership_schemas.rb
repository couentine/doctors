class Api::V1::Schemas::AppUserMembershipSchemas < Api::V1::Schemas::ApiSchema
  
  model :app_user_membership
  
  #=== FIELDS ===#

  field :type, :string,
    description: 'Controls the level of the user membership',
    enum_from: :type,
    default: :member

  field :status, :string,
    description: "Indicates the status of the membership.\n" \
      "- `pending` indicates that one or both sides still require approval\n" \
      "- `active` indicates that both sides have approved\n" \
      "- `disabled` indicates that one or both sides have denied",
    enum_from: :status,
    default: :active

  field :app_approval_status, :string,
    description: 'The app approval status controls the app side of the approval. Defaults to approved unless the membership ' \
      'is created by the user.',
    enum_from: :approval_status,
    default: :approved

  field :user_approval_status, :string,
    description: 'The user approval status controls the user side of the approval. Always defaults to approved.',
    enum_from: :approval_status,
    default: :approved

  field :app_id, [:string, :id],
    description: 'The id of the app'

  field :app_name, :string,
    description: 'The name of the app'

  field :user_id, [:string, :id],
    description: 'The id of the user who is the subject of the membership'

  field :user_name, :string,
    description: 'The name of the user'

  field :creator_id, [:string, :id],
    description: 'The id of the user who initially created the membership'

  #=== SCHEMAS ===#

  attributes_schema :output

  attributes_schema :input
  
  meta_schema :app

  relationship_schemas \
    user: 'The user who is the subject of the membership',
    groups: 'The app which is the subject of the membership',
    creator: 'The original creator of the membership'

end