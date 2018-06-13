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

  # The class instance variables hold the lists of settings for each deserializer:
  # - object_type = The JSON API type value (snake case symbol)
  # - fields = Array of all declared fields (items are hashes)
  # - target_field_for = Hash with a key for each field key and a value storing the target field in the created hash
  
  class << self
    attr_accessor :object_type, :fields, :target_field_for
  end

  # Aliases for hash and hashes will automatically be created based on object type
  # You shouldn't need to override the initialize method

  attr_reader :hash, :hashes, :params, :editable_fields

  # Accepts either an single param object or an array of param objects in the `:data` param.
  # You must pass a list of editable fields. This is used to filter the field values defined in the deserializer.
  # The target editable fields contain keys for the target fields not the deserializer fields (if different).
  def initialize(params, target_editable_fields)
    @hash = nil
    @hashes = nil
    @params = params
    @editable_fields = self.class.fields.select do |field|
      target_editable_fields.include? field[:target]
    end.map do |field|
      field[:name]
    end

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
      elsif item_params[:type].to_sym != self.class.object_type
        error_list << {
          message: "Type parameter is incorrect. Provided type is '#{item_params[:type]}'. " \
            "Required type for this object is '#{self.class.object_type}'.",
          pointer: (is_array ? "/data/#{index}/type" : "/data/type"),
        }
      else
        new_item = {}
        raw_item = item_params[:attributes].permit!.to_h

        raw_item.each do |key, value|
          if @editable_fields.include?(key.to_sym)
            new_item[self.class.target_field_for[key.to_sym]] = value
          else
            error_list << {
              message: "'#{key}' is not a valid editable field",
              pointer: (is_array ? "/data/#{index}/attributes/#{key}" : "/data/attributes/#{key}"),
            }
          end
        end

        new_items << new_item
      end
    end

    if error_list.present?
      raise Api::V1::DeserializationError.new(error_list)
    elsif is_array
      @hashes = new_items
    else
      @hash = new_items.first
    end
  end

  #=== TYPE DEFINITION ===#

  # USAGE:
  # 
  # type :endorsement
  # 
  # ==> CREATES INSTANCE METHODS: `endorsement`, `endorsements`
  # 
  # This sets the object type class instance variable. The JSON type key must match this exactly in order to be accepted.

  def self.type(object_type)
    @object_type = object_type

    # Declare singular getter
    send :define_method, object_type.to_sym do
      return hash
    end
    
    # Declare pllural getter
    send :define_method, object_type.to_s.pluralize.to_sym do
      return hashes
    end
  end

  #=== FIELD DEFINITIONS ===#
  
  # USAGE:
  # 
  # field :normal_non_renamed_field
  # field :renamed_field, target: :model_field
  # 
  # Only fields which are provided in the editable_fields list during initialization will be allowed, any others will raise an error.
  # Include an optional `target:` value if the source JSON key is different than the target field on the model.

  def self.field(field_name, target: nil)
    @fields = [] if @fields.nil?
    @target_field_for = {} if @target_field_for.nil?

    @fields << {
      name: field_name,
      target: target || field_name,
    }
    @target_field_for[field_name] = target || field_name
  end

end