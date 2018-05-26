module Api::V1::Helpers::OperationFormat::PaginatedList

  # EXAMPLE USAGE:
  # - model = :badge
  # - summary = 'Gets a list of all badges the current user has joined'
  def define_basic_info(model, summary, parent_model = nil, extra_permission = nil)
    camelized_model = model.to_s.camelize
    uncapitalized_camelized_model = camelized_model[0, 1].downcase + camelized_model[1..-1]
    permissions = ["- `all:index`", "- `#{model.to_s.pluralize}:read`"]
    permissions << "- `#{parent_model.to_s.pluralize}:read`" if parent_model.present?
    permissions << "- `#{extra_permission}`" if extra_permission.present?

    if parent_model.present?
      camelized_parent_model = parent_model.to_s.camelize
      uncapitalized_camelized_parent_model = camelized_parent_model[0, 1].downcase + camelized_parent_model[1..-1]
      
      key :operationId, "get#{camelized_parent_model}#{camelized_model.pluralize}"
    else
      key :operationId, "get#{camelized_model.pluralize}"
    end
    key :summary, summary
    key :tags, [
      'paginatedListFormat',
      "#{uncapitalized_camelized_model}Model"
    ]

    key :description, "-----\n" \
      "**Required Permissions:**\n" \
      + permissions.join("\n") + "\n" \
      "-----"
  end

  # EXAMPLE USAGE:
  # - model = :badge
  def define_index_parameters(model)
    controller_class_name = model.to_s.camelize.pluralize + 'Controller'
    sort_fields = "Api::V1::#{controller_class_name}::SORT_FIELDS".constantize
    default_sort_field = "Api::V1::#{controller_class_name}::DEFAULT_SORT_FIELD".constantize
    default_sort_order = "Api::V1::#{controller_class_name}::DEFAULT_SORT_ORDER".constantize
    default_sort_string = ((default_sort_order == :desc) ? '-' : '') + default_sort_field.to_s

    parameter do
      key :name, 'sort'
      key :in, :query
      key :description, 'Accepts a comma-separated list of fields to sort by. Fields are sorted ascending by default. To sort ' \
        'descending instead, place a hyphen (`-`) before the field name. For instance, `name,-created_at` would sort ascending by name, '\
        'then descending by creation date time. Allowed sort fields for this operation: ' + sort_fields.keys.join(', ')
      key :required, false
      key :type, :string
      key :default, default_sort_string
    end
    parameter do
      key :name, 'page[number]'
      key :in, :query
      key :description, "Specifies which page of results to return"
      key :required, false
      key :type, :integer
      key :default, 1
    end
    parameter do
      key :name, 'page[size]'
      key :in, :query
      key :description, "Specifies the maximum number of items to return in each page of results"
      key :minimum, Api::V1::BaseController::MIN_PAGE_SIZE
      key :maximum, Api::V1::BaseController::MAX_PAGE_SIZE
      key :required, false
      key :type, :integer
      key :default, APP_CONFIG['page_size_small']
    end
  end

  # EXAMPLE USAGE:
  # - model = :authentication_token
  # - include = [:relationships] >> Controls rendering of optional template pieces
  def define_success_response(model, include: [])
    camelized_model = model.to_s.camelize
    spaced_model = model.to_s.gsub('_', ' ')
    pluralized_spaced_model = spaced_model.pluralize

    response 200 do
      key :description, "Returns list of #{pluralized_spaced_model} in JSON API format."

      schema do
        key :type, :object
        
        # Root Data Key
        property :data do
          key :type, :array

          items do
            key :type, :object

            # Item Id & Type
            property :id do
              key :type, :string
              key :format, :id
              key :description, 'The unique identifier of this record'
              key :example, '841b90e775421f5205bf70a0'
            end
            property :type do
              key :type, :string
              key :enum, [model]
              key :description, "Will always be equal to `#{model.to_s}`"
            end

            # Item Attributes
            property :attributes do
              key :'$ref', "#{camelized_model}OutputAttributes"
            end

            # Item Relationships
            if (include.include? :relationships)
              property :relationships do
                key :'$ref', "#{camelized_model}Relationships"
              end
            end

            # Item Links
            property :links do
              key :'$ref', 'LinksObject'
            end
            
            # Item Meta
            property :meta do
              key :'$ref', "#{camelized_model}Meta"
            end
          end
        end

        # Root Meta Key
        property :meta do
          key :'$ref', 'RootMetaObjectWithPagination'
        end

        # Root JSON API Key
        property :jsonapi do
          key :'$ref', 'JsonApiObject'
        end
      end
    end
  end

end