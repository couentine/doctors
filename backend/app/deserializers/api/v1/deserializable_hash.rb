#==========================================================================================================================================#
# 
# DESERIALIZABLE HASH
# 
# This is the base deserializer. It deserializes into a vanilla ruby hash with only the allowed attributes and verifies that the type
# of each item equals the specified type. Any errors are raised as Api::V1::DeserializationError.
# 
# If params[:data] is a single record then `hash` will be set to a single hash and `hashes` will be nil.
# If params[:data] is an array then `hash` will be nil and `hashes` will be set to an array of hashes.
# 
#==========================================================================================================================================#

class Api::V1::DeserializableHash

  attr_reader :hash, :hashes

  TYPE = :hash
  ATTRIBUTES = []

  # Accepts either an single param object or an array of param objects in the `:data` param.
  def initialize(params)
    @hash = nil
    @hashes = nil

    # Check for corrupt params which would prevent parsing the data at all
    raise Api::V1::DeserializationError.new("The 'data' parameter is missing from the request body", '/data') if params[:data].nil?
    raise Api::V1::DeserializationError.new("The 'data' parameter is empty", '/data') if params[:data].blank?

    # Determine if there are multiple data items or not, then if not go ahead and encapsulate the single item in an array (to keep code dry)
    is_array = params[:data].class == Array
    data_item_params = (is_array) ? params[:data] : [params[:data]]
    
    # Loop through and attempt to deserialize each item, logging the errors along the way
    new_items = []
    error_list = []
    data_item_params.each_with_index do |item_params, index|
      if item_params[:type].blank?
        error_list << {
          message: 'Type parameter is missing',
          pointer: (is_array ? "/data/#{index}/type" : "/data/type"),
        }
      elsif item_params[:type].to_sym != self.class::TYPE
        error_list << {
          message: "Type parameter is incorrect. Provided type is '#{item_params[:type]}'. " \
            "Required type for this object is '#{self.class::TYPE}'.",
          pointer: (is_array ? "/data/#{index}/type" : "/data/type"),
        }
      else
        new_items << item_params[:attributes].permit!.to_h.select do |key, value|
          self.class::ATTRIBUTES.include?(key.to_sym)
        end
      end
    end

    if !error_list.empty?
      raise Api::V1::DeserializationError.new(error_list)
    elsif is_array
      @hashes = new_items
    else
      @hash = new_items.first
    end
  end

end