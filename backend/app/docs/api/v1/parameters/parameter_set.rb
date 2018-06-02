class Api::V1::Parameters::ParameterSet

  class << self
    attr_accessor :parameters
  end

  def self.parameter(name, parameter_key, in_the: :query, description: nil, type: :string, enum: nil, default: nil, required: false,
      maximum: nil, minimum: nil)
    @parameters = [] if @parameters.nil?

    @parameters << {
      name: name, 
      parameter_key: parameter_key, 
      in: in_the, 
      description: description, 
      type: type, 
      enum: enum, 
      required: required,
      default: default,
      maximum: maximum,
      minimum: minimum,
    }
  end

  # EXAMPLE USAGE:
  # 
  # define_filter_parameter :status, 'Filters based on user status:',
  #   all: 'includes all user stati',
  #   member: 'includes only users who are members',
  #   admin: includes only users who are admins',
  # 
  # Note: The first enum is always the default
  def self.filter_parameter(parameter_name, filter_key, description_header, enums_with_descriptions = {})
    parameter parameter_name, "filter[#{filter_key}]",
      description: "#{description_header}\n" + (
        enums_with_descriptions.map do |enum, description|
          "- `#{enum.to_s}` #{description}"
        end.join("\n")
      ),
      enum: enums_with_descriptions.keys,
      default: enums_with_descriptions.keys.first
  end


  # EXAMPLE USAGE:
  # - model = :badge
  def self.sort_parameter(model)
    controller_class_name = model.to_s.camelize.pluralize + 'Controller'
    sort_fields = "Api::V1::#{controller_class_name}::SORT_FIELDS".constantize
    default_sort_field = "Api::V1::#{controller_class_name}::DEFAULT_SORT_FIELD".constantize
    default_sort_order = "Api::V1::#{controller_class_name}::DEFAULT_SORT_ORDER".constantize
    default_sort_string = ((default_sort_order == :desc) ? '-' : '') + default_sort_field.to_s

    parameter "#{model.to_s}_sort", :sort,
      description: "Accepts a comma-separated list of fields to sort by. Fields are sorted ascending by default. To sort " \
        "descending instead, place a hyphen (`-`) before the field name. For instance, `name,-created_at` would sort ascending by name, "\
        "then descending by creation date time.\n" \
        "Allowed sort fields for this operation:\n" \
        "\n" \
        + (
          sort_fields.keys.map do |field_name|
            "- `#{field_name}`"
          end.join("\n")
        ),
      default: default_sort_string
  end

end