class Api::V1::SerializableAppGroupMembership < Api::V1::SerializableDocument
  type :app_group_membership

  #=== FIELDS ===#

  field :app_id
  field :group_id
  field :app_approval_status
  field :group_approval_status
  field :creator_id
  field :status
  
  field :app_name, from: :app_id do |app_group_membership|
    app_group_membership.app.name
  end
  field :group_name, from: :group_id do |app_group_membership|
    app_group_membership.group.name
  end
  
  #=== LINKS ===#

  self_links

  #=== RELATIONSHIPS ===#

  relationships \
    :app,
    :group,
    [:creator, :user, :creator_id]
end