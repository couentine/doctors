class Api::V1::Schemas::AppGroupMembershipSchemas < Api::V1::Schemas::ApiSchema
  
  model :app_group_membership
  
  #=== FIELDS ===#

  field :status, :string,
    description: "Indicates the status of the membership.\n" \
      "- `pending` indicates that one or both sides still require approval\n" \
      "- `active` indicates that both sides have approved\n" \
      "- `disabled` indicates that one or both sides have denied",
    enum_from: :status,
    default: :pending

  field :app_approval_status, :string,
    description: 'The app approval status controls the app side of the approval. Defaults to requested unless the membership ' \
      'is created by the app admins.',
    enum_from: :approval_status,
    default: :requested

  field :group_approval_status, :string,
    description: 'The group approval status controls the group side of the approval. Defaults to requested unless the membership ' \
      'is created by the group admins.',
    enum_from: :approval_status,
    default: :requested

  field :app_id, [:string, :id],
    description: 'The id of the app'

  field :app_name, :string,
    description: 'The name of the app'

  field :group_id, [:string, :id],
    description: 'The id of the group which is the subject of the membership'

  field :group_name, :string,
    description: 'The name of the group'

  field :creator_id, [:string, :id],
    description: 'The id of the user who initially created the membership'

  #=== SCHEMAS ===#

  attributes_schema :output

  attributes_schema :input
  
  meta_schema :app

  relationship_schemas \
    group: 'The group which is the subject of the membership',
    groups: 'The app which is the subject of the membership',
    creator: 'The original creator of the membership'

end