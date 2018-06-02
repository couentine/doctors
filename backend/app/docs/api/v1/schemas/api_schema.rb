class Api::V1::Schemas::ApiSchema
  include Swagger::Blocks

  FAKE_MONGODB_IDS = [
    '5936fced77898fa6ffc1cc78', '5936fd1077898fa6ffc1cc79', '5936fd2677898fa6ffc1cc7a', '593a19c077898f29b41576e9', 
    '5945cecb77898f4b356fee36', '5964259877898f27fe7c13e8', '598d074377898f2cf308709e', '599d000777898f58330a5346', 
    '59cab25f77898f1850337f6d', '59cae6c777898f1ee1775fb1', '59cb27cc77898f327c3fc568', '59cb2c0677898f327c3fc56e', 
    '59cb2cf977898f327c3fc572', '59cb33db77898f8bb99727c2', '59dfddf477898fcaa4ca9d79', '59fa1e3477898f48de112e33', 
    '5a73533077898f13c9033a2e', '5a7c924277898f34aa974370', '5a7cfdea77898f515b1c3352', '5a7cfdea77898f515b1c3354'
  ];

  # The class instance variables hold the lists of settings for each schema:
  # - api_model = The name of the model within the API
  # - model_class = The database model class (used to pull enums and length constants)
  # - fields = All declared fields (items are hashes)
  # - field_map = Hash mapping from field name to field hash
  # - schema_field_for = Hash mapping from policy field name to schema field name
  
  class << self
    attr_accessor :api_model, :model_class, :fields, :field_map, :schema_field_for
  end

  #=== MODEL DEFINITION ===#

  # USAGE:
  # 
  # model :authentication_token #==> Sets api model and model class to AuthenticationToken
  # model :portfolio, class: Entry #==> Sets api model to Portfolio and model class to Entry

  def self.model(api_model, model_class: nil)
    @api_model = api_model.to_s.camelize
    @model_class = model_class || @api_model.constantize
  end

  #=== FIELD DEFINITION ===#

  # USAGE:
  # 
  # field :name, :string, description: 'Description text', max: 140
  # field :summary, :string, max_from: :summary
  # field :status, :string, enum_from: :status, default: :active
  # field :website, [:string, :url], example: 'https://www.example.com'
  # 
  # Declare all of the fields up top, then you can use the schema definition methods to define the schemas automatically 
  # based on the serializers / deserializers.
  # 
  # NOTE: String fields with format `:id` will automatically have a realistic mongodb id generated for them.

  def self.field(name, type_info, description: nil, example: nil, enum: nil, max: nil, enum_from: nil, max_from: nil, required: nil, 
      default: nil)
    @fields = [] if @fields.nil?
    @field_map = {} if @field_map.nil?
    @schema_field_for = {} if @schema_field_for.nil?

    if type_info.class == Array
      type = type_info.first
      format = type_info.last
    else
      type = type_info
    end

    field = {
      name: name,
      type: type,
      format: format,
      description: description,
      enum: enum,
      max_length: max,
      required: required,
      default: default,
    }
    field[:max_length] = "#{@model_class}::MAX_#{max_from.upcase}_LENGTH".constantize if max_from.present?
    field[:enum] = "#{@model_class}::#{enum_from.upcase}_VALUES".constantize if enum_from.present?
    field[:example] = example if example != nil #==> ensures that `false` boolean example values get included
    if field[:example].nil? && (field[:type] == :string) && (field[:format] == :id)
      field[:example] = FAKE_MONGODB_IDS.sample
    end

    @fields << field
    @field_map[name] = field
  end

  #=== ATTRIBUTES SCHEMA GENERATION ===#

  # USAGE:
  # 
  # attributes_schema :output
  # attributes_schema :input
  # 
  # Generates the appropriate schema including all fo the fields defined in the serializer (output) or the deserializer (input).
  # Automatically raises an exception if there are fields in the source class which are not defined in the schema class.
  # Also raises an exception if there are any declared schema fields which do *not* have a match in the source class.

  def self.attributes_schema(source)
    class_key = (source == :input) ? 'Deserializable' : 'Serializable'
    schema_class = self
    unmatched_fields = @field_map.keys
    source_class = "Api::V1::#{class_key}#{@api_model}".constantize
    schema_name = "#{@api_model}#{source.to_s.camelize}Attributes".to_sym

    swagger_schema schema_name do
      extend Api::V1::Helpers::SchemaHelpers::CommonDocumentFields if source == :output

      key :type, :object

      source_class.fields.each do |source_field|
        schema_field = schema_class.field_map[source_field[:name]]
        raise ArgumentError.new("#{schema_class.name} is missing field definition for :#{source_field[:name].to_s}") if schema_field.blank?
        
        unmatched_fields.delete(schema_field[:name])
        if source == :output  
          schema_class.schema_field_for[source_field[:from]] = schema_field[:name]
        end

        property source_field[:name] do
          key :type, schema_field[:type]
          key :format, schema_field[:format] if schema_field[:format].present?
          key :max_length, schema_field[:max_length] if schema_field[:max_length].present?
          key :enum, schema_field[:enum] if schema_field[:enum].present? && (schema_field[:type] != :array)
          key :default, schema_field[:default] if schema_field[:default].present?
          key :required, true if schema_field[:required] == true
          key :description, schema_field[:description]
          key :example, schema_field[:example] if schema_field.has_key?(:example)

          if schema_field[:enum].present? && (schema_field[:type] == :array)
            items do
              key :type, :string
              key :enum, schema_field[:enum]
            end
          end
        end
      end

      if unmatched_fields.present? && (source == :output) #==> input won't have all the fields
        raise ArgumentError.new(
          "The following schema fields have no matching fields in #{source_class.name}: #{unmatched_fields.join(', ')}"
        )
      end
    end
  end

  #=== META SCHEMA GENERATION ===#

  # USAGE:
  # 
  # meta_schema :creator
  # 
  # Automatically finds the policy class for this model and generates the appropriate meta schema. In order to use this, you must 
  # specify the belongs_to relationship (from the source policy class) to use to generate the list of editable fields.

  def self.meta_schema(editable_fields_parent_relationship)
    source_class = "#{@api_model}Policy".constantize
    schema_name = "#{@api_model}Meta".to_sym
    schema_class = self

    swagger_schema schema_name do
      key :type, :object

      property :current_user do
        key :type, :object
        
        property :roles do
          key :type, :array
          key :description, "List of the current user's roles with respect to this record. The available roles are different for " \
            "each model. A user's roles help determine the actions they are allowed to take on the record within the API."

          items do
            key :type, :string
            key :enum, source_class.roles
          end
        end
        property :allowed_actions do
          key :type, :array
          key :description, 'List of the record actions which are permitted to the current user based on their roles'

          items do
            key :type, :string
            key :enum, (
              source_class.actions.map do |action|
                action[:name]
              end.select do |action_name|
                (action_name != :create) \
                && (action_name != :show) \
                && !action_name.to_s.ends_with?('index')
              end
            )
          end
        end
        property :editable_fields do
          key :type, :array
          key :description, "If the current user is allowed to update this record, this contains a list of all of the fields which are " \
            "based on the user's roles"

          items do
            key :type, :string
            key :enum, (
              source_class.get_creation_fields_for(editable_fields_parent_relationship).map do |field_name|
                schema_class.schema_field_for[field_name]
              end.select do |field_name|
                field_name.present?
              end
            )
          end
        end
      end

      if source_class.features.present?
        property :available_features do
          key :type, :array
          key :description, 'Includes a list of features which are available for this record. The available features help determine ' \
            'which actions are permitted on that record within the API.'

          items do
            key :type, :string
            key :enum, source_class.features
          end
        end
      end
    end
  end

  #=== RELATIONSHIP SCHEMA GENERATION ===#

  # USAGE:
  # 
  # relationship_schemas \
  #   user: 'The user to which the membership belongs',
  #   app: 'The app to which the user is subscribed'
  # 
  # This is a simple shortcut for the boilerplate code required to register multiple relationship objects.
  # It doesn't do anything too fancy, since the documentation of the relationship objects is pretty bare bones at this point.
  # This method utilizes the RelationshipsList schema helper to build the actual swagger blocks syntax.

  def self.relationship_schemas(relationships)
    schema_name = "#{@api_model}Relationships".to_sym

    swagger_schema schema_name do
      extend Api::V1::Helpers::SchemaHelpers::RelationshipsList

      key :type, :object

      relationships.each do |relationship_name, description|
        define_relationship_property relationship_name, description
      end
    end
  end

end