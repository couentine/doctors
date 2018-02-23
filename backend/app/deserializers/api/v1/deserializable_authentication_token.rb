class Api::V1::DeserializableAuthenticationToken < Api::V1::DeserializableDocument

  @type = 'authentication_token'
  @attributes = ['user_id', 'permission_sets']
  @document_class = AuthenticationToken

end