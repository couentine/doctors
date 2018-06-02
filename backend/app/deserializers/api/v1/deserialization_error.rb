class Api::V1::DeserializationError < StandardError 
  attr_reader :error_list

  # Each deserialization item needs a message and a json pointer to the location of the field in the passed params.
  # 
  # TO CREATE A SINGLE ERROR: initialize(message, pointer)
  # `DeserializationError.new('Data parameter is missing from body', '/data')`
  # 
  # TO CREATE MULTIPLE ERRORS: initialize(error_list)
  # ```
  #   DeserializationError.new([
  #     { message: 'Name is missing', pointer: '/data/2/attributes/name' },
  #     { message: 'Type is invalid', pointer: '/data/7/type' },
  #   ])
  # ```
  # 
  def initialize(*args)
    if args[0].class == Array
      @error_list = args[0]
    else
      @error_list = [
        {
          message: args[0],
          pointer: args[1],
        }
      ]
    end
  end

  # Returns the error_list formatted as a json api `errors` key.
  def to_json_api
    json_api_formatted_error_list = error_list.map do |error_item|
      {
        title: error_item[:message],
        source: {
          pointer: error_item[:pointer]
        }
      }
    end

    return {
      errors: json_api_formatted_error_list,
      jsonapi: {
        version: '1.0'
      },
    }
  end

  def to_s
    to_json_api.to_s
  end
end