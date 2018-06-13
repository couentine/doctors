class Api::V1::Parameters::BadgeParameters < Api::V1::Parameters::ParameterSet

  parameter :badge_id, :id,
    in_the: :path,
    description: 'The id of the badge record',
    required: true

  parameter :badge_badge_id, :badge_id,
    in_the: :path,
    description: 'The id of the badge record',
    required: true

  parameter :badge_key, :key,
    in_the: :path,
    description: "The badge key can be any of the following:\n" \
      "- Record id\n" \
      "- Badge slug (case insensitive)",
    required: true

  filter_parameter :badge_membership_status, :status,
    "Filters badges based on user's membership status:",
    all: 'includes all badges which the user has joined',
    seeker: 'includes only badges for which the user is a seeker',
    holder: 'includes only badges for which the user is a holder'

  sort_parameter :badge

end