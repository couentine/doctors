#==========================================================================================================================================#
# 
# DESERIALIZABLE DOCUMENT
# 
# This is the base deserializer for mongoid documents. It deserializes into the specified mongoid document class with only the allowed 
# attributes and verifies that the type of each item equals the specified type. Any errors are raised as Api::V1::DeserializationError.
# 
# If params[:data] is a single record then `document` will be set to a single document and `documents` will be nil.
# If params[:data] is an array then `document` will be nil and `documents` will be set to an array of documents.
# 
#==========================================================================================================================================#

class Api::V1::DeserializableDocument < Api::V1::DeserializableHash

  attr_reader :document, :documents

  TYPE = :document
  DOCUMENT_CLASS = Mongoid::Document

  # This builds a new record (or an array of new records) from the provided JSON API formatted params.
  # Accepts either an single param object or an array of param objects in the `:data` param.
  def initialize(params)
    @document = nil
    @documents = nil

    # Call the DeserializableHash initializer to parse the params and raise any errors
    super(params)

    # If we make it to this line then we know that the input params were valid and either @hash or @hashes is set
    # Next step is to convert the hash/hashes into documents of the appropriate class

    # Determine if there are multiple data items or not, then if not go ahead and encapsulate the single item in an array (to keep code dry)
    is_array = @hashes.present?
    items_list = is_array ? @hashes : [@hash]
    
    # Loop through and attempt to convert each hash into a document instance, logging the errors along the way
    new_documents = []
    error_list = []
    items_list.each_with_index do |item, index|
      begin
        new_documents << self.class::DOCUMENT_CLASS.new(item)
      rescue => e
        error_list << {
          message: e.message,
          pointer: (is_array ? "/data/#{index}/attributes" : "/data/attributes"),
        }
      end
    end

    if !error_list.empty?
      raise Api::V1::DeserializationError.new(error_list)
    elsif is_array
      @documents = new_documents
    else
      @document = new_documents.first
    end
  end

end