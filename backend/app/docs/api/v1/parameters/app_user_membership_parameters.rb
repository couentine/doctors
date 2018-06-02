class Api::V1::Parameters::AppUserMembershipParameters < Api::V1::Parameters::ParameterSet

  parameter :app_user_membership_id, :id,
    in_the: :path,
    description: 'The id of the app user membership record',
    required: true

  filter_parameter :app_user_membership_status, :status,
    'Filters memerships based on their status:',
    all: 'includes all memberships regardless of status',
    pending: 'includes memberships which are pending approval by the user or the app',
    active: 'includes memberships which are active',
    disabled: 'includes memberships which have been denied by the user or the group'

  filter_parameter :app_user_membership_type, :type,
    'Filters memerships based on their type:',
    all: 'includes all memberships regardless of type',
    member: 'includes only member type memberships',
    admin: 'includes only admin memberships'

  filter_parameter :app_user_membership_app_approval_status, :app_approval_status,
    'Filters memerships based on whether the app admins have approved the membership:',
    all: 'includes all memberships regardless of status',
    requested: 'includes only memberships which are waiting for app approval',
    approved: 'includes only memberships which have been approved by the app',
    denied: 'includes only memberships which have been denied by the app'

  filter_parameter :app_user_membership_user_approval_status, :user_approval_status,
    'Filters memerships based on whether the user has approved the membership:',
    all: 'includes all memberships regardless of status',
    requested: 'includes only memberships which are waiting for user approval',
    approved: 'includes only memberships which have been approved by the user',
    denied: 'includes only memberships which have been denied by the user'

  sort_parameter :app_user_membership

end