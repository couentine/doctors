module Api::V1::Helpers::OperationFormat::Base

  def define_error_response(status_code, error_object_schema, description_text)
    response status_code do
      key :description, description_text

      schema do
        key :type, :object
        
        # Errors Key
        property :errors do
          key :type, :array

          items do
            key :'$ref', error_object_schema
          end
        end

        # Root Meta Key
        property :meta do
          key :'$ref', 'RootMetaObjectWithPermissionSets'
        end

        # JSON API Key
        property :jsonapi do
          key :type, :object

          property :version do
            key :type, :string
            key :enum, ['1.0']
          end
        end
      end # schema tag 
    end # response block
  end

  # Adds a standard 403 response
  def define_unauthorized_response
    define_error_response 403, :GenericErrorObject, 'Authentication details are incorrect or missing. ' \
      'Or the authenticated user does not have access to the requested operation.'
  end

  # Adds a standard 404 response
  def define_not_found_response
    define_error_response 404, :GenericErrorObject, 'The specified record could not be found.'
  end

  # Adds field specific errors of 400 type
  def define_field_error_response
    define_error_response 400, :FieldErrorObject, 'One or more field values in the request body were invalid.'
  end
  
end