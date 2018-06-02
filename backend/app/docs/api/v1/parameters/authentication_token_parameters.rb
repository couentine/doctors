class Api::V1::Parameters::AuthenticationTokenParameters < Api::V1::Parameters::ParameterSet

  parameter :authentication_token_id, :id,
    in_the: :path,
    description: 'The id of the authentication token record',
    required: true

  sort_parameter :authentication_token

end