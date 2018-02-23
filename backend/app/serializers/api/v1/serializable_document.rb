class Api::V1::SerializableDocument < JSONAPI::Serializable::Resource
    
  id { @object.id.to_s }

  attribute :created_at do
    @object.created_at.to_i if @object.created_at
  end

  attribute :updated_at do
    @object.updated_at.to_i if @object.updated_at
  end

  meta do
    if @meta.present?
      @meta
    elsif @meta_index.present?
      @meta_index[@object.id.to_s]
    else
      nil
    end
  end

end