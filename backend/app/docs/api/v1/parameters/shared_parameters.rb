class Api::V1::Parameters::SharedParameters < Api::V1::Parameters::ParameterSet

  parameter :page_number, :'page[number]',
    description: "Specifies which page of results to return",
    type: :integer,
    default: 1

  parameter :page_size, :'page[size]',
    description: 'Specifies the maximum number of items to return in each page of results',
    minimum: Api::V1::BaseController::MIN_PAGE_SIZE,
    maximum: Api::V1::BaseController::MAX_PAGE_SIZE,
    type: :integer,
    default: APP_CONFIG['page_size_small']  

end