class Api::V1::Parameters::UserParameters < Api::V1::Parameters::ParameterSet

  parameter :user_key, :key,
    in_the: :path,
    description: "You can query user records using any of the following keys:\n" \
      "- Record id\n" \
      "- Username (case insensitive)\n" \
      "- Email address (case insensitive)",
    required: true

  parameter :user_user_key, :user_key,
    in_the: :path,
    description: "You can query user records using any of the following keys:\n" \
      "- Record id\n" \
      "- Username (case insensitive)\n" \
      "- Email address (case insensitive)",
    required: true

  filter_parameter :user_group_membership_type, :status,
    "Filters groups based on users' group membership type:",
    all: 'includes all users',
    member: 'includes only member users',
    admin: 'includes only admin users'

  sort_parameter :user

end