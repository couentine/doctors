module Api::V1::Helpers::OperationFormat::BatchOperation

  # - verb = one of >> [:get, :create, :update, :delete]
  def define_basic_info(model, verb, summary = nil, parent_model = nil, description = nil)
    camelized_model = model.to_s.camelize
    uncapitalized_camelized_model = camelized_model[0, 1].downcase + camelized_model[1..-1]
    spaced_model = model.to_s.gsub('_', ' ')

    if parent_model.present?
      camelized_parent_model = parent_model.to_s.camelize
      uncapitalized_camelized_parent_model = camelized_parent_model[0, 1].downcase + camelized_parent_model[1..-1]
      permissions = ApplicationPolicy.get_action_permissions(parent_model, model, :create).map{ |item| "- `#{item}`" }

      key :operationId, "#{verb.to_s}#{camelized_parent_model}#{camelized_model.pluralize}"
    else
      permissions = ApplicationPolicy.get_action_permissions(model, :create).map{ |item| "- `#{item}`" }

      key :operationId, "#{verb.to_s}#{camelized_model.pluralize}"
    end
    key :summary, summary
    key :tags, ['batchOperationFormat', "#{uncapitalized_camelized_model}Model"]

    key :description, "#{description}\n" \
      "\n" \
      "-----\n" \
      "**Required Permissions:**\n" \
      + permissions.join("\n") + "\n" \
      "-----"
  end

  # Optionally include a hash of meta_properties with keys equal to the meta properties and values equal 
  # to hashes of the swagger block settings.
  def define_post_parameters(model: nil, verb: :create, meta_properties: nil)
    camelized_model = model.to_s.camelize
    spaced_model = model.to_s.gsub('_', ' ')

    parameter do

      key :name, :body
      key :in, :body
      key :description, "The JSON API formatted details of the #{spaced_model.to_s} items to #{verb.to_s}"
      
      schema do
        key :type, :object
        key :required, [:data]

        # Data Key
        property :data do
          key :type, :array
          key :description, "**Note:** This can be either an array *or* a single object. Passing an array will trigger 'batch mode', " \
            "while passing an object will trigger 'single mode'."
          key :minItems, 1
          key :maxItems, APP_CONFIG['max_import_list_size']

          items do
            key :type, :object

            # Item Type
            property :type, type: :string, enum: [model], description: "Must always be equal to `#{model.to_s}`"

            # Item Attributes
            property :attributes do
              key :'$ref', "#{camelized_model}InputAttributes"
            end
          end
        end
        
        # Meta Key
        if meta_properties.present?
          property :meta do
            key :type, :object

            meta_properties.each do |key, settings|
              property key, settings
            end
          end
        end
      end

    end
  end

  def define_success_responses(model)
    camelized_model = model.to_s.camelize

    response 201 do
      key :description, 'When the passed `data` parameter is single object, the operation runs synchronously and returns the result.'

      schema do
        key :type, :object
        
        # Root Data Key
        property :data do
          key :type, :object

          property :type do
            key :type, :string
            key :enum, ["#{model}_result"]
          end

          # Item Attributes
          property :attributes do    
            key :'$ref', "#{camelized_model.capitalize}ResultAttributes"
          end
        end

        # Root Meta Key
        property :meta do
          key :'$ref', 'RootMetaObject'
        end

        # Root JSON API Key
        property :jsonapi do
          key :'$ref', 'JsonApiObject'
        end
      end
    end

    response 202 do
      key :description, 'When the passed `data` parameter is an array, the operation runs asynchronously and returns a poller ' \
        'which can be used to track the progress.'

      schema do
        key :type, :object
        
        # Root Data Key
        property :data do
          key :type, :object

          # Item Id & Type
          property :id do
            key :type, :string
            key :format, :id
            key :description, 'The unique identifier of the poller record'
            key :example, '841b90e775421f5205bf70a0'
          end
          property :type do
            key :type, :string
            key :enum, [:poller]
          end

          # Item Attributes
          property :attributes do
            key :type, :object

            property :status do
              key :type, :string
              key :enum, [:pending]
            end

            property :results do
              key :type, :array

              items do
                key :'$ref', "#{camelized_model.capitalize}ResultAttributes"
              end
            end
          end

          # Item Links
          property :links do
            key :'$ref', 'LinksObject'
          end

        end

        # Root Meta Key
        property :meta do
          key :'$ref', 'RootMetaObject'
        end

        # Root JSON API Key
        property :jsonapi do
          key :'$ref', 'JsonApiObject'
        end
      end
    end
  end

end