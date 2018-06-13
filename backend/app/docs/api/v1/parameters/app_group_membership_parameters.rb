class Api::V1::Parameters::AppGroupMembershipParameters < Api::V1::Parameters::ParameterSet

  parameter :app_group_membership_id, :id,
    in_the: :path,
    description: 'The id of the app user membership record',
    required: true

  filter_parameter :app_group_membership_status, :status,
    'Filters memerships based on their status:',
    all: 'includes all memberships regardless of status',
    pending: 'includes memberships which are pending approval by the group or the app',
    active: 'includes memberships which are active',
    disabled: 'includes memberships which have been denied by the group or the group'

  filter_parameter :app_group_membership_app_approval_status, :app_approval_status,
    'Filters memerships based on whether the app admins have approved the membership:',
    all: 'includes all memberships regardless of status',
    requested: 'includes only memberships which are waiting for app approval',
    approved: 'includes only memberships which have been approved by the app',
    denied: 'includes only memberships which have been denied by the app'

  filter_parameter :app_group_membership_group_approval_status, :group_approval_status,
    'Filters memerships based on whether the group admins have approved the membership:',
    all: 'includes all memberships regardless of status',
    requested: 'includes only memberships which are waiting for group approval',
    approved: 'includes only memberships which have been approved by the group',
    denied: 'includes only memberships which have been denied by the group'

  sort_parameter :app_group_membership

end