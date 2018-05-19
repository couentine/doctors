class Api::V1::SerializableGroup < Api::V1::SerializableDocument
  extend JSONAPI::Serializable::Resource::ConditionalFields

  type 'group'

  attribute :slug do @object.url_with_caps end

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

  link :self do "/api/v1/groups/#{@object.id.to_s}" end
  link :self_web do @object.full_url end

  has_many :badges do
    link :self do "/api/v1/groups/#{@object.id.to_s}/badges" end
  end
  has_many :users do
    link :self do "/api/v1/groups/#{@object.id.to_s}/users" end
  end

end