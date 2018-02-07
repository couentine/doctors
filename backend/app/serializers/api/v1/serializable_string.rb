class Api::V1::SerializableString < JSONAPI::Serializable::Resource
  attribute :value do self end
end