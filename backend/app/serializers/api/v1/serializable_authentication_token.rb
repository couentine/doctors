class Api::V1::SerializableAuthenticationToken < Api::V1::SerializableDocument
  extend JSONAPI::Serializable::Resource::ConditionalFields

  type 'authentication_token'

  attribute :value

  attribute :permission_sets

  attribute :request_count
  attribute :last_used_at
  attribute :ip_address
  attribute :user_agent

  link :self do "/api/v1/authentication_tokens/#{@object.id.to_s}" end
  # link :self_web do @object.full_url end

  belongs_to :user do
    link :self do "/api/v1/users/#{@object.user_id.to_s}" end
  end
  belongs_to :creator, if: -> { @object.creator_id.present? } do
    link :self do "/api/v1/users/#{@object.creator_id.to_s}" end
  end

end