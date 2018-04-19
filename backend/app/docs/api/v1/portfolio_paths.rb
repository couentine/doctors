class Api::V1::PortfolioPaths
  include Swagger::Blocks

  swagger_path '/portfolios/{id}' do
    
    #=== GET PORTFOLIO ===#

    operation :get do
      extend Api::V1::SharedOperationFormats::Base
      extend Api::V1::SharedOperationFormats::RecordItem

      # Basic Info
      define_basic_info :portfolio, :get

      # Parameters
      parameter do
        key :name, :id
        key :format, :id
        key :in, :path
        key :description, 'The id of the portfolio record'
        key :required, true
        key :type, :string
      end

      # Responses
      define_success_response :portfolio, 200, include: [:relationships]
      define_unauthorized_response
      define_not_found_response
    end

  end

end