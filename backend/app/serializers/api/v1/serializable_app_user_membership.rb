class Api::V1::SerializableAppUserMembership < Api::V1::SerializableDocument
  type :app_user_membership

  #=== FIELDS ===#

  field :app_id
  field :user_id
  field :type
  field :app_approval_status
  field :user_approval_status
  field :creator_id
  field :status

  field :app_name, from: :app_id do |app_user_membership|
    app_user_membership.app.name
  end
  field :user_name, from: :user_id do |app_user_membership|
    app_user_membership.user.name
  end
  
  #=== LINKS ===#

  self_links

  #=== RELATIONSHIPS ===#

  relationships \
    :app,
    :user,
    [:creator, :user, :creator_id]
end