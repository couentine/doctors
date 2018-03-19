class Api::V1::ErrorSchemas
  include Swagger::Blocks

  #=== GENERIC ERROR OBJECT ===#

  swagger_schema :GenericErrorObject do
    
    key :type, :object
    
    property :status do
      key :type, :integer
      key :enum, [400, 403]
      key :description, 'HTTP status code of the error'
    end
    property :title do
      key :type, :string
      key :description, 'Error title'
    end
    property :detail do
      key :type, :string
      key :description, 'Error detail'
    end

  end

  #=== FIELD ERROR OBJECT ===#

  swagger_schema :FieldErrorObject do
    
    key :type, :object
    
    property :title do
      key :type, :string
      key :description, 'Error title'
    end
    property :detail do
      key :type, :string
      key :description, 'Error detail'
    end
    property :source do
      key :type, :object

      property :pointer do
        key :type, :string
        key :format, :pointer
        key :description, 'A JSON pointer (in accordance with the RFC6901 specification) to the part of the request document which was ' \
          'in error. Example: `/data/attributes/name`'
      end
    end

  end

end