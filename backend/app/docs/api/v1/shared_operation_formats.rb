module Api::V1::SharedOperationFormats

  #=== COMMON TEMPLATES ===#

  module Base

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
    
  end
  
  #=== RECORD ITEM FORMAT ===#

  module RecordItem

    # EXAMPLE USAGE:
    # - model = :authentication_token
    # - verb = one of >> [:get, :create, :update, :delete]
    def define_basic_info(model, verb)
      camelized_model = model.to_s.camelize
      uncapitalized_camelized_model = camelized_model[0, 1].downcase + camelized_model[1..-1]
      spaced_model = model.to_s.gsub('_', ' ')

      key :operationId, "#{verb.to_s}#{camelized_model}"
      
      case verb
      when :get
        key :summary, "Get a #{spaced_model} record by id"
      when :create
        key :summary, "Create a new #{spaced_model} record"
      when :update
        key :summary, "Update an existing #{spaced_model} record by id"
      when :delete
        key :summary, "Delete an existing #{spaced_model} record by id"
      end
        
      key :tags, [
        'recordItemFormat',
        "#{uncapitalized_camelized_model}Model"
      ]
    end

    # EXAMPLE USAGE:
    # - item_model = :badge
    # - parent_model = :group (If parent model is left out then no parent_path parameter is included)
    def define_id_parameters(item_model, parent_model = nil)
      spaced_item_model = item_model.to_s.gsub('_', ' ')
      description_text = "The id or the (case-insensitive) slug of the #{spaced_item_model} record."
      if parent_model.present?
        description_text += " If you use the slug then you must also specify the `parent_path` parameter."
      end

      parameter do
        key :name, :id
        key :format, :id
        key :in, :path
        key :description, description_text
        key :required, true
        key :type, :string
      end
      if parent_model.present?
        parameter do
          key :name, :parent_path
          key :in, :query
          key :description, "The slug or id of the parent #{parent_model} record. " \
            "Only specify this parameter if you are using the slug as the value in the `id` parameter."
          key :type, :string
          key :required, false
        end
      end
    end

    # EXAMPLE USAGE:
    # - model = :badge
    def define_post_parameters(model)
      camelized_model = model.to_s.camelize
      spaced_model = model.to_s.gsub('_', ' ')

      parameter do

        key :name, model
        key :in, :body
        key :description, "The JSON API formatted details of the new #{spaced_model.to_s} record"
        key :required, true
        
        schema do
          key :type, :object

          # Data Key
          property :data do
            key :type, :object

            # Item Type
            property :type, type: :string, enum: [model], description: "Must always be equal to `#{model.to_s}`"

            # Item Attributes
            property :attributes do
              key :'$ref', "#{camelized_model}InputAttributes"
            end
          end
        end

      end
    end

    # EXAMPLE USAGE:
    # - model = :authentication_token
    # - include = [:relationships] >> Controls rendering of optional template pieces
    def define_success_response(model, response_code, include: [])
      camelized_model = model.to_s.camelize
      spaced_model = model.to_s.gsub('_', ' ')

      response response_code do
        key :description, "Returns #{spaced_model} details in JSON API format."

        schema do
          key :type, :object
          
          # Root Data Key
          property :data do
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
              key :type, :object
              
              property :self, type: :string, format: :url
            end
            
            # Item Meta
            property :meta do
              key :'$ref', "#{camelized_model}Meta"
            end
          end

          # Root Meta Key
          property :meta do
            key :type, :object

            property :authentication_method, type: :string, enum: [:token, :session, :none]
          end

          # Root JSON API Key
          property :jsonapi do
            key :type, :object

            property :version do
              key :type, :string
              key :enum, ['1.0']
            end
          end
        end
      end
    end

    # Adds a standard 403 response
    def define_field_error_response
      define_error_response 400, :FieldErrorObject, 'One or more field values in the request body were invalid.'
    end
    
  end

  #=== PAGINATED LIST FORMAT ===#

  module PaginatedList

    # EXAMPLE USAGE:
    # - model = :badge
    # - summary = 'Gets a list of all badges the current user has joined'
    def define_basic_info(model, summary)
      camelized_model = model.to_s.camelize
      uncapitalized_camelized_model = camelized_model[0, 1].downcase + camelized_model[1..-1]

      key :operationId, "#{uncapitalized_camelized_model}Index"
      key :summary, summary
      key :tags, [
        'paginatedListFormat',
        "#{uncapitalized_camelized_model}Model"
      ]
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
                key :type, :object
                
                property :self, type: :string, format: :url
              end
              
              # Item Meta
              property :meta do
                key :'$ref', "#{camelized_model}Meta"
              end
            end
          end

          # Root Meta Key
          property :meta do
            key :type, :object

            property :authentication_method, type: :string, enum: [:token, :session, :none]

            property :page do
              key :type, :object
              
              property :number do
                key :type, :integer
                key :description, 'The current page of results'
              end
              property :size do
                key :type, :integer
                key :description, 'The maximum number of items per page of results'
              end
              property :prev do
                key :type, :integer
                key :description, 'The page number of the previous page of results if there is one'
              end
              property :next do
                key :type, :integer
                key :description, 'The page number of the next page of results if there is one'
              end
              property :last do
                key :type, :integer
                key :description, 'The page number of the final page of results'
              end
            end
            property :sort do
              key :type, :string
              key :description, 'Indicates the sort which was used to order the results'
            end
            property :filter do
              key :type, :object
              key :description, 'Indicates the filter settings which were used to filter the results'
            end
          end

          # Root JSON API Key
          property :jsonapi do
            key :type, :object

            property :version do
              key :type, :string
              key :enum, ['1.0']
            end
          end
        end
      end
    end
  end

end