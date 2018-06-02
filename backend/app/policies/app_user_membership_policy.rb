class AppUserMembershipPolicy < ApplicationPolicy

  record_decorators 'AppUserMembershipDecorator::UserMembershipDecorator'

  #=== ACTION POLICIES ===#

  standard_actions :app_user_membership,
    show_roles: :all_roles,
    update_roles: [:app_admin, :user_self],
    destroy_roles: [:app_admin, :user_self]
  
  #=== RELATIONSHIP POLICIES ===#

  belongs_to :app,
    via: :app_id,
    visible_to: :all_roles,
    creation_role: :app_admin

  belongs_to :user,
    via: :user_id,
    visible_to: :all_roles,
    creation_role: :user_self

  belongs_to :creator,
    policy_model: :user,
    via: :creator_id,
    visible_to: :all_roles

  #=== FIELD POLICIES ===#

  APP_ADMIN_FIELD = { visible_to: :all_roles, editable_by: [:app_admin] }
  USER_SELF_FIELD = { visible_to: :all_roles, editable_by: [:user_self] }
  READ_ONLY_FIELD = { visible_to: :all_roles, editable_by: :nobody }

  field :type,                          APP_ADMIN_FIELD
  field :app_approval_status,           APP_ADMIN_FIELD

  field :user_approval_status,          USER_SELF_FIELD
  
  field :status,                        READ_ONLY_FIELD

  #=== ROLE DEFINITIONS ===#

  role :user_self do |current_user, app_user_membership|
    current_user.present? && (current_user.id == app_user_membership.user_id)
  end
  
  role :app_admin do |current_user, app_user_membership|
    current_user.present? && app_user_membership.parent_app.has_admin?(current_user)
  end

end