class Api::V1::SerializableAuthenticationToken < Api::V1::SerializableDocument
  type :authentication_token

  #=== FIELDS ===#

  field :name
  field :user_id
  field :permissions

  field :value

  field :request_count
  field :last_used_at,        convert: :iso8601
  field :ip_address
  field :user_agent
  
  field :creator_id

  #=== LINKS ===#

  link :self do "/api/v1/authentication_tokens/#{@object.id.to_s}" end
  # link :self_web do @object.full_url end

  #=== RELATIONSHIPS ===#

  relationships \
    :user
    [:creator, :user, :creator_id]
end