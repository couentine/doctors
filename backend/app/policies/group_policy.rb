class GroupPolicy < ApplicationPolicy

  #=== ACTION POLICIES ===#
  
  standard_actions :group,
    show_roles: :everyone,
    update_roles: [:admin, :owner],
    destroy_roles: [:owner]
  
  action :members_index,
    roles: [:member_list_viewer, :member, :admin, :owner],
    permissions: ['all:index', 'users:read']
  
  action :admins_index,
    roles: [:admin_list_viewer, :member, :admin, :owner],
    permissions: ['all:index', 'users:read']

  #=== RELATIONSHIP POLICIES ===#

  belongs_to :creator,
    via: :creator_id,
    policy_model: :user,
    visible_to: :everyone,
    creation_role: :owner,
    read_only: true

  belongs_to :owner,
    via: :owner_id,
    policy_model: :user,
    visible_to: :everyone,
    creation_role: :owner,
    read_only: true

  has_many :app_group_memberships,
    visible_to: [:member_list_viewer, :member, :admin, :owner],
    creatable_by: [:admin, :owner]

  has_and_belongs_to_many :users,
    visible_to: [:member_list_viewer, :member, :admin, :owner]

  has_and_belongs_to_many :badges,
    visible_to: :everyone

  has_and_belongs_to_many :apps,
    visible_to: [:member_list_viewer, :member, :admin, :owner]


  #=== FIELD POLICIES ===#

  OWNER_FIELD = { visible_to: :everyone, editable_by: [:owner] }
  ADMIN_FIELD = { visible_to: :everyone, editable_by: [:admin] }
  READ_ONLY_FIELD = { visible_to: :all_roles, editable_by: :nobody }
  PRIVATE_ADMIN_FIELD = { visible_to: [:admin], editable_by: [:admin] }
  PRIVATE_BL_ADMIN_FIELD = { visible_to: [:bl_admin], editable_by: [:bl_admin] }

  field :name,                                    OWNER_FIELD
  field :url_with_caps,                           OWNER_FIELD
  field :description,                             OWNER_FIELD
  field :location,                                OWNER_FIELD
  field :website,                                 OWNER_FIELD
  field :type,                                    OWNER_FIELD
  field :subscription_plan,                       OWNER_FIELD
  field :joinability,                             OWNER_FIELD
  field :new_owner_username,                      OWNER_FIELD
  field :member_visibility,                       OWNER_FIELD
  field :admin_visibility,                        OWNER_FIELD
  field :badge_copyability,                       OWNER_FIELD
  
  field :color,                                   ADMIN_FIELD
  field :tag_assignability,                       ADMIN_FIELD
  field :tag_creatability,                        ADMIN_FIELD
  field :tag_visibility,                          ADMIN_FIELD

  field :member_count,                            READ_ONLY_FIELD
  field :admin_count,                             READ_ONLY_FIELD
  field :total_user_count,                        READ_ONLY_FIELD
  field :badge_count,                             READ_ONLY_FIELD
  
  field :join_code,                               PRIVATE_ADMIN_FIELD

  field :feature_grant_file_uploads,              PRIVATE_BL_ADMIN_FIELD
  field :feature_grant_reporting,                 PRIVATE_BL_ADMIN_FIELD
  field :feature_grant_bulk_tools,                PRIVATE_BL_ADMIN_FIELD
  field :feature_grant_integration,               PRIVATE_BL_ADMIN_FIELD
  field :feature_grant_hub,                       PRIVATE_BL_ADMIN_FIELD
  field :feature_grant_leaderboards_weekly,       PRIVATE_BL_ADMIN_FIELD
  field :feature_grant_leaderboards_realtime,     PRIVATE_BL_ADMIN_FIELD

  #=== ROLE DEFINITIONS ===#
  
  # This only needs to capture folks who aren't already members/admins/other roles
  role :member_list_viewer do |current_user, group|
    group.member_visibility == 'public'
  end

  # This only needs to capture folks who aren't already members/admins/other roles
  role :admin_list_viewer do |current_user, group|
    group.admin_visibility == 'public'
  end

  role :member do |current_user, group|
    current_user.present? && current_user.member_of?(group)
  end

  role :admin do |current_user, group|
    current_user.present? && current_user.admin_of?(group)
  end

  role :owner do |current_user, group|
    current_user.present? && (current_user.id == group.owner_id)
  end

  #=== SCOPES ===#

  # Builds a scope criteria which includes all of the groups for a particular target user which the current user can see.
  # This scope incorporates the target user's group settings (show_on_profile) for each group and cross-references the current user's
  # memberships with the member / admin visibilities of each group.
  # NOTE: Instead of passing a mongoid criteria as a scope, pass a string which is equal to `member`, `admin` or `all`. This scope class
  #   will build the scope from scratch.
  class UserScope < ApplicationPolicy::Scope
    attr_reader :current_user, :scope, :target_user

    # scope = `member`, `admin` or `all`
    def initialize(current_user, scope, target_user)
      @current_user = current_user
      @scope = scope
      @target_user = target_user
    end

    def resolve
      # First build a list of the groups which have been hidden on the user's profile (only needed if this isn't the current user)
      # NOTE: The group settings list is NOT populated for all groups and it defaults to showing the group, so it's best to build a list
      #   of hidden groups rather than trying to build a list of visible groups (otherwise we'll be missing the groups which aren't in the 
      #   group settings).
      if @current_user != @target_user
        hidden_group_ids = @target_user.group_settings.map do |group_id, group_settings| 
          group_settings['show_on_profile'] ? nil : group_id
        end.select do |group_id| 
          group_id.present?
        end
      end

      # Then move forward with buidling the scopes
      if @current_user == @target_user
        if @scope == 'admin'
          return @target_user.admin_of
        elsif @scope == 'member'
          return @target_user.member_of
        else
          return Group.where(:id.in => (@target_user.admin_of_ids + @target_user.member_of_ids))
        end
      elsif @current_user.present?
        if @scope == 'admin'
          non_hidden_admin_ids = @target_user.admin_of_ids.map(&:to_s) - hidden_group_ids
          shared_group_ids = non_hidden_admin_ids & (@current_user.admin_of_ids.map(&:to_s) + @current_user.member_of_ids.map(&:to_s))

          return Group.any_of(
            {:id.in => shared_group_ids},
            {:id.in => non_hidden_admin_ids, admin_visibility: 'public'}
          )
        elsif @scope == 'member'
          non_hidden_member_ids = @target_user.member_of_ids.map(&:to_s) - hidden_group_ids
          shared_group_ids = non_hidden_member_ids & (@current_user.admin_of_ids.map(&:to_s) + @current_user.member_of_ids.map(&:to_s))

          return Group.any_of(
            {:id.in => shared_group_ids},
            {:id.in => non_hidden_member_ids, member_visibility: 'public'}
          )
        else
          non_hidden_admin_ids = @target_user.admin_of_ids.map(&:to_s) - hidden_group_ids
          non_hidden_member_ids = @target_user.member_of_ids.map(&:to_s) - hidden_group_ids
          all_non_hidden_group_ids = non_hidden_admin_ids + non_hidden_member_ids
          shared_group_ids = all_non_hidden_group_ids & (@current_user.admin_of_ids.map(&:to_s) + @current_user.member_of_ids.map(&:to_s))
          
          return Group.any_of(
            {:id.in => shared_group_ids},
            {:id.in => non_hidden_admin_ids, admin_visibility: 'public'},
            {:id.in => non_hidden_member_ids, member_visibility: 'public'}
          )
        end
      else
        if @scope == 'admin'
          non_hidden_admin_ids = @target_user.admin_of_ids.map(&:to_s) - hidden_group_ids

          return Group.where(:id.in => non_hidden_admin_ids, admin_visibility: 'public')
        elsif @scope == 'member'
          non_hidden_member_ids = @target_user.member_of_ids.map(&:to_s) - hidden_group_ids
          
          return Group.where(:id.in => non_hidden_member_ids, member_visibility: 'public')
        else
          non_hidden_admin_ids = @target_user.admin_of_ids.map(&:to_s) - hidden_group_ids
          non_hidden_member_ids = @target_user.member_of_ids.map(&:to_s) - hidden_group_ids

          return Group.any_of(
            {:id.in => non_hidden_admin_ids, admin_visibility: 'public'},
            {:id.in => non_hidden_member_ids, member_visibility: 'public'}
          )
        end
      end
    end
  end

end