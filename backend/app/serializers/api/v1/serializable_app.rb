class Api::V1::SerializableApp < Api::V1::SerializableDocument
  type :app

  #=== FIELDS ===#

  field :name
  field :slug
  field :summary
  field :user_joinability
  field :group_joinability

  field :status
  field :review_status
  
  field :description
  field :organization
  field :website
  field :email

  field :image_url
  field :image_medium_url, from: :image_url do |app|
    app.image_url(:medium)
  end
  field :image_small_url, from: :image_url do |app|
    app.image_url(:small)
  end
  field :processing_image

  field :user_count
  field :group_count
  
  field :owner_id
  field :creator_id
  
  #=== LINKS ===#

  self_links

  #=== RELATIONSHIPS ===#

  relationships \
    :users,
    :groups,
    :app_user_memberships,
    :app_group_memberships, 
    [:owner, :user, :owner_id], 
    [:creator, :user, :creator_id]
end