class Api::V1::Parameters::PortfolioParameters < Api::V1::Parameters::ParameterSet

  parameter :portfolio_id, :id,
    in_the: :path,
    description: 'The id of the portfolio record',
    required: true

  filter_parameter :portfolio_status, :status, 
    'Filters portfolios based on their status within the feedback/awarding process:',
    all: 'includes all portfolios regardless of status',
    draft: 'includes portfolios which have not yet been submitted for feedback',
    requested: 'includes portfolios which have requested but not yet received feedback',
    endorsed: 'includes portfolios which have been awarded'

  sort_parameter :portfolio

end