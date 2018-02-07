class Api::V1::SerializableBadge < Api::V1::SerializableDocument
  extend JSONAPI::Serializable::Resource::ConditionalFields

  type 'badge'

  attribute :record_path
  attribute :parent_path
  attribute :slug do @object.url end
  attribute :slug_with_caps do @object.url_with_caps end
  attribute :current_user_permissions
  
  attribute :name
  attribute :summary

  attribute :validation_request_count
  attribute :learner_count
  attribute :image_url
  attribute :image_medium_url
  attribute :image_small_url

  link :self do @object.full_path end
  link :parent do "/#{@object.group_url_with_caps || @object.group.url_with_caps}" end

end