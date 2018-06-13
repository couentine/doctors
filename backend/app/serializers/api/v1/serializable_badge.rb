class Api::V1::SerializableBadge < Api::V1::SerializableDocument
  type :badge

  #=== FIELDS ===#

  field :slug,                          from: :url_with_caps
  
  field :name
  field :summary
  field :visibility

  field :feedback_request_count,        from: :validation_request_count
  field :seeker_count,                  from: :learner_count
  field :holder_count,                  from: :expert_count
  
  field :image_url
  field :image_medium_url
  field :image_small_url

  field :group_id
  field :creator_id

  #=== LINKS ===#
  
  self_links
  
  #=== RELATIONSHIPS ===#
  
  relationships \
    :group,
    :portfolios,
    [:creator, :user, :creator_id]
end