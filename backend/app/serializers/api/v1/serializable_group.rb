class Api::V1::SerializableGroup < Api::V1::SerializableDocument
  type :group

  #=== FIELDS ===#

  field :slug,                          from: :url_with_caps

  field :name
  field :summary,                       from: :description
  field :location
  field :type
  field :color

  field :image_url,                     from: :avatar_image_url
  field :image_medium_url,              from: :avatar_image_medium_url
  field :image_small_url,               from: :avatar_image_small_url
  
  field :member_count
  field :admin_count
  field :total_user_count
  field :badge_count

  field :member_visibility
  field :admin_visibility
  field :badge_copyability

  field :owner_id
  field :creator_id

  #=== LINKS ===#
  
  self_links
  
  #=== RELATIONSHIPS ===#
  
  relationships \
    :badges,
    :users,
    :apps,
    :app_group_memberships,
    [:owner, :user, :owner_id], 
    [:creator, :user, :creator_id]
end