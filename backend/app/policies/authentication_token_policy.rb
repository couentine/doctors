class AuthenticationTokenPolicy < ApplicationPolicy

  #=== ACTION POLICIES ===#

  standard_actions :authentication_token,
    show_roles: :all_roles,
    update_roles: [:admin],
    destroy_roles: [:admin]

  #=== RELATIONSHIP POLICIES ===#

  belongs_to :user,
    via: :user_id,
    visible_to: :all_roles,
    creation_role: :admin

  belongs_to :creator,
    via: :creator_id,
    policy_model: :user,
    visible_to: :all_roles,
    creation_role: :admin,
    read_only: true

  #=== FIELD POLICIES ===#

  ADMIN_FIELD = { visible_to: [:admin], editable_by: [:admin] }
  READ_ONLY_FIELD = { visible_to: [:admin], editable_by: :nobody }
  SECRET_FIELD = { visible_to: [:admin], editable_by: :nobody, secret: true }

  field :name,                          ADMIN_FIELD
  field :permissions,                   ADMIN_FIELD

  field :request_count,                 READ_ONLY_FIELD
  field :last_used_at,                  READ_ONLY_FIELD
  field :ip_address,                    READ_ONLY_FIELD
  field :user_agent,                    READ_ONLY_FIELD

  field :value,                         SECRET_FIELD

  #=== ROLE DEFINITIONS ===#

  role :admin do |current_user, authentication_token|
    next false if current_user.blank?

    if authentication_token.user
      if authentication_token.user.type == 'individual'
        # Tokens for individual users can only be created by the users themselves
        next current_user.id == authentication_token.user.id
      elsif (authentication_token.user.type == 'group') && authentication_token.user.proxy_group
        # Tokens for group users can only be created by group admins
        next current_user.admin_of?(authentication_token.user.proxy_group)
      elsif (authentication_token.user.type == 'app') && authentication_token.user.proxy_app
        # Tokens for app users can only be created by app admins
        next AppUserMembershipDecorator.new(authentication_token.user.proxy_app).has_admin? current_user
      end
    else
      next false
    end
  end

  #=== SCOPES ===#

  class Scope < ApplicationPolicy::Scope
    def resolve
      if @current_user.present?
        scope.where(user_id: @current_user.id)
      else
        nil
      end
    end
  end

end