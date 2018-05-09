module Api::V1::Helpers::OperationFormat::RecordItem

  # EXAMPLE USAGE:
  # - model = :authentication_token
  # - verb = one of >> [:get, :create, :update, :delete]
  def define_basic_info(model, verb, summary = nil, parent_model = nil)
    camelized_model = model.to_s.camelize
    uncapitalized_camelized_model = camelized_model[0, 1].downcase + camelized_model[1..-1]
    spaced_model = model.to_s.gsub('_', ' ')

    if parent_model.present?
      camelized_parent_model = parent_model.to_s.camelize
      uncapitalized_camelized_parent_model = camelized_parent_model[0, 1].downcase + camelized_parent_model[1..-1]
    end

    if parent_model.present?
      key :operationId, "#{verb.to_s}#{camelized_parent_model}#{camelized_model}"
    else
      key :operationId, "#{verb.to_s}#{camelized_model}"
    end
    
    if summary.blank?
      case verb
      when :get
        key :summary, "Get #{spaced_model} by id"
      when :create
        key :summary, "Create a new #{spaced_model} record"
      when :update
        key :summary, "Update an existing #{spaced_model} record by id"
      when :delete
        key :summary, "Delete an existing #{spaced_model} record by id"
      end
    else
      key :summary, summary
    end
      
    key :tags, ['recordItemFormat', "#{uncapitalized_camelized_model}Model"]
  end

  # EXAMPLE USAGE:
  # - model = :badge
  def define_post_parameters(model)
    camelized_model = model.to_s.camelize
    spaced_model = model.to_s.gsub('_', ' ')

    parameter do

      key :name, :body
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
  # - suppress = [:meta] >> keeps meta from being included
  def define_success_response(model, response_code, include: [], exclude: [], description: nil)
    camelized_model = model.to_s.camelize
    spaced_model = model.to_s.gsub('_', ' ')

    response response_code do
      if description.blank?
        key :description, "Returns #{spaced_model} details in JSON API format."
      else
        key :description, description
      end

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
          if include.include?(:relationships)
            property :relationships do
              key :'$ref', "#{camelized_model}Relationships"
            end
          end

          # Item Links
          property :links do
            key :'$ref', 'LinksObject'
          end
          
          # Item Meta
          if !exclude.include?(:meta)
            property :meta do
              key :'$ref', "#{camelized_model}Meta"
            end
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