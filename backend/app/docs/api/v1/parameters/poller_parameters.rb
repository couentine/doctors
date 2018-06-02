class Api::V1::Parameters::PollerParameters < Api::V1::Parameters::ParameterSet

  parameter :poller_id, :id,
    in_the: :path,
    description: 'The id of the poller record',
    required: true

end