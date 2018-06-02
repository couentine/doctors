class Api::V1::Paths::PollerPaths
  include Swagger::Blocks

  swagger_path '/pollers/{id}' do
    
    #=== GET POLLER ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

      # Basic Info
      define_basic_info :poller, :get, 'Get poller by id'

      # Parameters
      parameter :poller_id

      # Responses
      define_success_response :poller, 200, exclude: [:meta]
      define_not_found_response
    end

  end

end