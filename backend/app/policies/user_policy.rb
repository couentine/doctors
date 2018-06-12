class UserPolicy < ApplicationPolicy

  #=== ACTION POLICIES ===#

  standard_actions :user,
    show_roles: :everyone,
    update_roles: [:self],
    destroy_roles: [:self]

  #=== RELATIONSHIP POLICIES ===#

  belongs_to :proxy_app,
    via: :proxy_app_id,
    policy_model: :app,
    visible_to: :everyone,
    read_only: true

  belongs_to :proxy_group,
    via: :proxy_group_id,
    policy_model: :group,
    visible_to: :everyone,
    read_only: true

  has_many :app_user_memberships,
    visible_to: [:self, :proxy_admin],
    creatable_by: [:self, :proxy_admin]

  has_many :authentication_tokens,
    visible_to: [:self, :proxy_admin],
    creatable_by: [:self, :proxy_admin]

  has_many :portfolios,
    visible_to: :all_roles,
    creatable_by: [:self]

  has_and_belongs_to_many :apps,
    visible_to: [:self]

  has_and_belongs_to_many :groups,
    visible_to: [:self]

  #=== FIELD POLICIES ===#

  SELF_FIELD = { visible_to: :all_roles, editable_by: [:self] }
  READ_ONLY_FIELD = { visible_to: :all_roles, editable_by: :nobody }
  PRIVATE_READ_ONLY_FIELD = { visible_to: :self, editable_by: :nobody }

  field :username_with_caps,            SELF_FIELD
  field :avatar_image_url,              SELF_FIELD
  field :name,                          SELF_FIELD
  field :job_title,                     SELF_FIELD
  field :organization_name,             SELF_FIELD
  field :website,                       SELF_FIELD
  field :bio,                           SELF_FIELD
  field :email,                         SELF_FIELD
  field :password,                      SELF_FIELD
  
  field :expert_badge_count,            READ_ONLY_FIELD
  
  field :is_private,                    READ_ONLY_FIELD
  field :email_verification_needed,     READ_ONLY_FIELD
  field :email_inactive,                READ_ONLY_FIELD
  field :identity_hash,                 READ_ONLY_FIELD
  field :identity_salt,                 READ_ONLY_FIELD
  field :avatar_image_medium_url,       READ_ONLY_FIELD
  field :avatar_image_small_url,        READ_ONLY_FIELD
  field :type,                          READ_ONLY_FIELD
  field :last_active,                   READ_ONLY_FIELD

  field :async_callback_poller_id,      PRIVATE_READ_ONLY_FIELD

  #=== ROLE DEFINITIONS ===#

  role :viewer do |current_user, user|
    !user.has_private_domain || user.profile_visible_to(current_user)
  end
  
  role :self do |current_user, user|
    current_user.present? && (current_user.id == user.id)
  end
  
  role :proxy_admin do |current_user, user|
    next false if user.type == 'individual'

    if (user.type == 'group') && user.proxy_group
      next current_user.admin_of?(user.proxy_group)
    elsif (user.type == 'app') && user.proxy_app
      next AppUserMembershipDecorator.new(user.proxy_app).has_admin?(current_user)
    else
      next false
    end
  end

  #=== SCOPES ===#

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end

end