class Api::V1::DeserializableApp < Api::V1::DeserializableDocument
  type :app

  #=== FIELDS ===#

  field :name
  field :slug
  field :summary
  field :user_joinability
  field :group_joinability

  field :review_status
  
  field :description
  field :organization
  field :website
  field :email
  
  field :image_url, target: :new_image_url
end
