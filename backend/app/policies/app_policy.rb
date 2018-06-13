class AppPolicy < ApplicationPolicy

  record_decorators :app_user_membership_decorator

  #=== ACTION POLICIES ===#

  standard_actions :app,
    show_roles: :everyone,
    update_roles: [:admin],
    destroy_roles: [:owner]

  action :join_as_user,
    roles: [:joinable_non_member_user],
    permissions: ['current_user:manage', 'app_user_memberships:write']

  action :join_as_group,
    roles: [:joinable_non_member_group],
    permissions: ['groups:manage', 'app_group_memberships:write']
  
  #=== RELATIONSHIP POLICIES ===#

  belongs_to :owner,
    via: :owner_id,
    policy_model: :user,
    visible_to: :everyone,
    creation_role: :owner,
    read_only: true

  belongs_to :creator,
    via: :creator_id,
    policy_model: :user,
    visible_to: :everyone,
    creation_role: :owner,
    read_only: true

  has_many :app_user_memberships,
    visible_to: [:admin],
    creatable_by: [:admin]

  has_many :app_group_memberships,
    visible_to: [:admin],
    creatable_by: [:admin]

  has_and_belongs_to_many :users,
    visible_to: [:admin]

  has_and_belongs_to_many :groups,
    visible_to: [:admin]

  #=== FIELD POLICIES ===#

  OWNER_FIELD = { visible_to: :everyone, editable_by: [:owner] }
  ADMIN_FIELD = { visible_to: :everyone, editable_by: [:admin] }
  BL_ADMIN_FIELD = { visible_to: :everyone, editable_by: [:bl_admin] }
  READ_ONLY_FIELD = { visible_to: :everyone, editable_by: :nobody }

  field :review_status,                 BL_ADMIN_FIELD

  field :name,                          OWNER_FIELD
  field :slug,                          OWNER_FIELD
  
  field :user_joinability,              ADMIN_FIELD
  field :group_joinability,             ADMIN_FIELD
  field :summary,                       ADMIN_FIELD
  field :description,                   ADMIN_FIELD
  field :organization,                  ADMIN_FIELD
  field :website,                       ADMIN_FIELD
  field :email,                         ADMIN_FIELD
  field :new_image_url,                 ADMIN_FIELD
  
  field :required,                      READ_ONLY_FIELD
  field :status,                        READ_ONLY_FIELD
  field :image_url,                     READ_ONLY_FIELD
  field :processing_image,              READ_ONLY_FIELD
  field :user_count,                    READ_ONLY_FIELD
  field :group_count,                   READ_ONLY_FIELD

  #=== ROLE DEFINITIONS ===#

  # This role captures users who aren't a member but could be.
  role :joinable_non_member_user do |current_user, app|
    (app.user_joinability != 'closed') \
      && (!current_user.present? || !app.has_user_membership?(current_user))
  end

  # This role captures group proxy users who aren't a member but could be.
  role :joinable_non_member_group do |current_user, app|
    (app.group_joinability != 'closed') \
      && current_user.present? && (current_user.type == 'group') && current_user.proxy_group_id.present? \
      && !AppGroupMembershipDecorator.new(app).has_group_membership?(current_user.proxy_group_id)
  end

  role :member_user do |current_user, app|
    current_user.present? && app.has_user_membership?(current_user)
  end
  
  role :admin do |current_user, app|
    current_user.present? && app.has_admin?(current_user)
  end
  
  role :owner do |current_user, app|
    current_user.present? && (app.owner_id == current_user.id)
  end

end