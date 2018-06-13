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

  # This class inherits the accessors from the DeserializableHash class. In addition it has the following:
  # - document_class = The class used to instantiate / update items
  
  class << self
    attr_accessor :document_class
  end

  # Aliases for document and documents will automatically be created based on object type
  # You shouldn't need to override the initialize method

  attr_reader :document, :documents

  # This builds a new record (or an array of new records) from the provided JSON API formatted params.
  # Accepts either an single param object or an array of param objects in the `:data` param.
  # If this is an update to an existing record then include it in the `existing_document` argument.
  def initialize(params, target_editable_fields, existing_document: nil)
    @document = existing_document
    @documents = nil

    # Call the DeserializableHash initializer to parse the params and raise any errors
    super(params, target_editable_fields)

    # If we make it to this line then we know that the input params were valid and either @hash or @hashes is set
    # Next step is to convert the hash/hashes into documents of the appropriate class
    
    is_array = @hashes.present?
    error_list = []

    if is_array
      @documents = []

      @hashes.each_with_index do |hash, index|
        begin
          @documents << self.class.document_class.new(hash)
        rescue => e
          error_list << {
            message: e.message,
            pointer: "/data/#{index}/attributes",
          }
        end
      end
    else
      begin
        if @document.present?
          @document.assign_attributes(@hash)
        else
          @document = self.class.document_class.new(@hash)
        end
      rescue => e
        error_list << {
          message: e.message,
          pointer: '/data/attributes',
        }
      end
    end

    raise Api::V1::DeserializationError.new(error_list) if error_list.present?
  end

  #=== TYPE DEFINITION ===#

  # EXAMPLE 1:
  # type :badge
  # 
  # EXAMPLE 2:
  # type :portfolio, class: Log
  # 
  # ==> CREATES INSTANCE METHODS: `portolfio`, `portolfios`
  # 
  # This sets the object type class instance variable. The JSON type key must match this exactly in order to be accepted.
  # If `class:` is left off, the class is assumed to be the camelized version of the object type.

  def self.type(object_type, document_class: nil)
    @object_type = object_type
    @document_class = document_class || object_type.to_s.camelize.constantize

    # Declare singular getter
    send :define_method, object_type.to_sym do
      return document
    end
    
    # Declare pllural getter
    send :define_method, object_type.to_s.pluralize.to_sym do
      return documents
    end
  end

  #=== FIELD DEFINITIONS ===#

  # Field definition works exactly the same as it does for DeserializableHash.
  # Refer to the comments in DeserializableHash for documentation of the syntax.

end