class Api::V1::Parameters::GroupParameters < Api::V1::Parameters::ParameterSet

  parameter :group_key, :key,
    in_the: :path,
    description: "You can query group records using any of the following keys:\n" \
      "- Record id\n" \
      "- Group slug (case insensitive)",
    required: true

  parameter :group_group_key, :group_key,
    in_the: :path,
    description: "You can query group records using any of the following keys:\n" \
      "- Record id\n" \
      "- Group slug (case insensitive)",
    required: true

  filter_parameter :group_membership_status, :status,
    "Filters groups based on user's membership status:",
    all: 'includes all groups for which the user is a member or an admin',
    member: 'includes only groups for which the user is a member',
    admin: 'includes only groups for which the user is an admin'

  sort_parameter :group

end