class AppGroupMembershipPolicy < ApplicationPolicy

  #=== ACTION POLICIES ===#

  standard_actions :app_group_membership,
    show_roles: :all_roles,
    update_roles: [:group_admin, :app_admin],
    destroy_roles: [:group_admin, :app_admin]
  
  #=== RELATIONSHIP POLICIES ===#

  belongs_to :app,
    via: :app_id,
    visible_to: :all_roles,
    creation_role: :app_admin

  belongs_to :group,
    via: :group_id,
    visible_to: :all_roles,
    creation_role: :group_admin

  belongs_to :creator,
    policy_model: :user,
    via: :creator_id,
    visible_to: :all_roles

  #=== FIELD POLICIES ===#

  APP_ADMIN_FIELD = { visible_to: :all_roles, editable_by: [:app_admin] }
  GROUP_ADMIN_FIELD = { visible_to: :all_roles, editable_by: [:group_admin] }
  READ_ONLY_FIELD = { visible_to: :all_roles, editable_by: :nobody }
  
  field :app_approval_status,           APP_ADMIN_FIELD
  
  field :group_approval_status,         GROUP_ADMIN_FIELD

  field :status,                        READ_ONLY_FIELD

  #=== ROLE DEFINITIONS ===#

  role :group_viewer do |current_user, app_group_membership|
    !app_group_membership.group.has?(:privacy)
  end

  role :group_member do |current_user, app_group_membership|
    current_user.present? && current_user.member_of?(app_group_membership.group_id)
  end

  role :group_admin do |current_user, app_group_membership|
    current_user.present? && current_user.admin_of?(app_group_membership.group_id)
  end

  role :app_admin do |current_user, app_group_membership|
    current_user.present? \
      && AppUserMembershipDecorator.new(app_group_membership.app).has_admin?(current_user)
  end

end