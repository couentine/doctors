class Api::V1::DeserializableAuthenticationToken < Api::V1::DeserializableDocument

  type :authentication_token

  field :name
  field :user_id
  field :permissions

end