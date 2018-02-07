class Api::V1::SerializableAuthenticationToken < Api::V1::SerializableDocument

  type 'authentication_token'

  attribute :record_path do @object.id.to_s end
  attribute :parent_path do nil end

  attribute :value do @object.user_id.to_s + @object.body.to_s end
  attribute :request_count
  attribute :last_used_at
  attribute :ip_address
  attribute :user_agent

  # This hasn't been added to the UI yet, so we don't know what the link will be:
  # link :self do; "???/#{@object.id.to_s}"; end

end