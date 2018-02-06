class Api::V1::SerializableDocument < JSONAPI::Serializable::Resource
  id { @object.id.to_s }

  attribute :created_at do
    @object.created_at.to_i if @object.created_at
  end

  attribute :updated_at do
    @object.updated_at.to_i if @object.updated_at
  end
end