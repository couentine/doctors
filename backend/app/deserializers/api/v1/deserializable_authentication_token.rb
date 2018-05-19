class Api::V1::DeserializableAuthenticationToken < Api::V1::DeserializableDocument

  attr_reader :authentication_token, :authentication_tokens

  TYPE = :authentication_token
  ATTRIBUTES = [:user_id, :permission_sets]
  DOCUMENT_CLASS = AuthenticationToken

  def initialize(params)
    @authentication_token = nil
    @authentication_tokens = nil

    super(params)

    @authentication_token = @document
    @authentication_tokens = @documents
  end

end