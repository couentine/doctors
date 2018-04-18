class Api::V1::SerializableUser < Api::V1::SerializableDocument
  extend JSONAPI::Serializable::Resource::ConditionalFields

  type 'user'

  attribute :username do @object.username_with_caps end
  attribute :is_private
  attribute :email_hash do @object.identity_hash end
  attribute :email_salt do @object.identity_salt end

  attribute :image_url do @object.avatar_image_url end
  attribute :image_medium_url do @object.avatar_image_medium_url end
  attribute :image_small_url do @object.avatar_image_small_url end

  attribute :type,                  if: -> { @show_all_fields }
  attribute :name,                  if: -> { @show_all_fields }
  
  attribute :job_title,             if: -> { @show_all_fields }
  attribute :organization_name,     if: -> { @show_all_fields }
  attribute :website,               if: -> { @show_all_fields }
  attribute :bio,                   if: -> { @show_all_fields }
  
  attribute :last_active,           if: -> { @show_all_fields } do
    @object.last_active.iso8601 if @object.last_active
  end

  link :self do "/api/v1/users/#{@object.id.to_s}" end

  belongs_to :proxy_group,          if: -> { @object.proxy_group_id.present? } do
    link :self do "/api/v1/groups/#{@object.proxy_group_id.to_s}" end
  end
  has_many :groups do
    link :self do "/api/v1/users/#{@object.id.to_s}/groups" end
  end
  has_many :portfolios do
    link :self do "/api/v1/users/#{@object.id.to_s}/portfolios" end
  end

end