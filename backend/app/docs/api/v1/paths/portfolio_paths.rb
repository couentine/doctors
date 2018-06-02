class Api::V1::Paths::PortfolioPaths
  include Swagger::Blocks

  swagger_path '/portfolios/{id}' do
    
    #=== GET PORTFOLIO ===#

    operation :get do
      extend Api::V1::Helpers::OperationFormat::Base
      extend Api::V1::Helpers::OperationFormat::RecordItem

      # Basic Info
      define_basic_info :portfolio, :get

      # Parameters
      parameter :portfolio_id

      # Responses
      define_success_response :portfolio, 200, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

  end

end