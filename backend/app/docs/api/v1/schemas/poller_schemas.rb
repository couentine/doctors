class Api::V1::Schemas::PollerSchemas
  include Swagger::Blocks

  #=== POLLER OUTPUT ATTRIBUTES ===#

  swagger_schema :PollerOutputAttributes do
    extend Api::V1::Helpers::SchemaHelpers::CommonDocumentFields

    key :type, :object

    property :status do
      key :type, :string
      key :enum, [:pending, :successful, :failed]
      key :description, 'The current status of the poller'
    end

    property :progress do
      key :type, :integer
      key :description, 'If the poller tracks progress then this will be a number from 0 to 100, otherwise it will be null'
      key :example, 42
    end

    property :completed do
      key :type, :boolean
      key :description, 'Returns true if status is `successful` or `failed`'
      key :example, false
    end

    property :waiting_message do
      key :type, :string
      key :description, 'The user-facing message displayed while the poller is active explaining the purpose of the poller'
      key :description, 'xxxx'
      key :example, 'Saving changes to the badge...'
    end

    property :completed_message do
      key :type, :string
      key :description, 'The user-facing message displayed after the poller is complete'
      key :example, 'Badge update complete.'
    end

    property :results do
      key :type, :array
      key :description, 'For bulk asynchronous actions which accept an array of items in the request, the results array is used to ' \
        'return the processed result of each request item. The results array is always the same size as the request items array and ' \
        'each result item will be at the same index as its corresponding request item.'
      
      items do
        key :type, :object

        property :type do
          key :type, :string
          key :description, 'A string indicating the result of the bulk action for this item. For a complete list of all of the ' \
            'possible result types refer to the documentation for the originating action.'
          key :example, :success
        end
        property :success do
          key :type, :boolean
          key :description, 'True if result type was an error'
        end
        property :error_message do
          key :type, :string
          key :description, 'If the result type was an error then this field indicates the user-facing error message, otherwise it is null'
        end
      end
    end

  end

end