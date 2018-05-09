class Api::V1::SerializableBatchResult < JSONAPI::Serializable::Resource

  id { @object.id.to_s }

  type { @type }

  attribute :index
  attribute :type
  attribute :success
  attribute :error_message

end