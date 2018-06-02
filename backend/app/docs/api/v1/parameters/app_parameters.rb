class Api::V1::Parameters::AppParameters < Api::V1::Parameters::ParameterSet

  parameter :app_key, :key,
    in_the: :path,
    description: "The app key can be any of the following:\n" \
      "- Record id\n" \
      "- Badge slug (case insensitive)",
    required: true

  parameter :app_app_key, :app_key,
    in_the: :path,
    description: "The app key can be any of the following:\n" \
      "- Record id\n" \
      "- Badge slug (case insensitive)",
    required: true

  filter_parameter :app_status, :status,
    'Filters apps based on their status:',
    all: 'includes all apps regardless of status',
    pending: 'includes apps which are pending review by the Badge List team',
    active: 'includes apps which are active',
    disabled: 'includes apps which have been disabled by the admins'

  filter_parameter :app_user_joinability, :user_joinability,
    'Filters app based on the user joinability setting:',
    all: 'includes all apps regardless of user joinability',
    open: 'includes apps which can be freely joined by new users',
    by_request: 'includes apps which required new user memberships to be approved',
    closed: 'includes apps where only app admins can create new user memberships'

  filter_parameter :app_group_joinability, :group_joinability,
    'Filters app based on the group joinability setting:',
    all: 'includes all apps regardless of group joinability',
    open: 'includes apps which can be freely joined by new groups',
    by_request: 'includes apps which required new group memberships to be approved',
    closed: 'includes apps where only app admins can create new group memberships'

  sort_parameter :app

end