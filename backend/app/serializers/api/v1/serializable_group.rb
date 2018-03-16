class Api::V1::SerializableGroup < Api::V1::SerializableDocument
  extend JSONAPI::Serializable::Resource::ConditionalFields

  type 'group'

  attribute :slug do @object.url end
  attribute :slug_with_caps do @object.url_with_caps end

  attribute :name
  attribute :description
  attribute :location
  attribute :type
  attribute :color

  attribute :image_url do @object.avatar_image_url end
  attribute :image_medium_url do @object.avatar_image_medium_url end
  attribute :image_small_url do @object.avatar_image_small_url end
  
  attribute :member_count
  attribute :admin_count
  attribute :total_user_count
  attribute :badge_count

  link :self do; "/#{@object.url_with_caps}" end

end