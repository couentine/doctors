class Api::V1::DeserializableDocument

  @type = 'document'
  @attributes = []
  @document_class = Mongoid::Document

  # Converts json api formatted parameters to rails formatted parameters
  def self.convert_params(params)
    if params[:data][:type].blank?
      raise Api::V1::DeserializationError.new("Type parameter is missing.")
    elsif params[:data][:type] != @type
      raise Api::V1::DeserializationError.new(
        "Type parameter is incorrect. Provided type is '#{params[:data][:type]}'. Required type for this object is '#{@type}'."
      )
    end

    params[@type] = params[:data][:attributes].select do |key, value|
      @attributes.include?(key)
    end

    params[@type]['id'] = params[:data][:id] if params[:data][:id].present?
  end

  # This calls convert_params on the provided parameters, then uses them to build a new record using strong parameters
  def self.new_from(params)
    convert_params(params)

    return @document_class.new(params.require(@type).permit!)
  end

end