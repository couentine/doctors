class Api::V1::DeserializableAppGroupMembership < Api::V1::DeserializableDocument
  type :app_group_membership

  #=== FIELDS ===#

  field :app_id
  field :group_id
  field :app_approval_status
  field :group_approval_status
end
