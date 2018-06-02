class Api::V1::DeserializableAppUserMembership < Api::V1::DeserializableDocument
  type :app_user_membership

  #=== FIELDS ===#

  field :app_id
  field :user_id
  field :type
  field :app_approval_status
  field :user_approval_status
end
