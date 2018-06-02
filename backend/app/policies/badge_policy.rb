class BadgePolicy < ApplicationPolicy

  #=== ACTION POLICIES ===#

  standard_actions :badge,
    show_roles: :everyone,
    update_roles: [:editor],
    destroy_roles: [:admin]

  action :award,
    roles: [:awarder],
    permissions: ['portfolios:review']

  action :create_endorsement,
    roles: [:awarder],
    permissions: ['portfolios:review'],
    features: [:bulk_tools]

  action :portfolios_index,
    roles: [:portfolio_viewer, :seeker, :holder, :admin],
    permissions: ['all:index', 'portfolios:read']

  #=== RELATIONSHIP POLICIES ===#

  belongs_to :creator,
    via: :creator_id,
    policy_model: :user,
    visible_to: :all_roles,
    creation_role: :admin,
    read_only: true

  belongs_to :group,
    via: :group_id,
    visible_to: :everyone,
    creation_role: :admin

  has_many :portfolios,
    visible_to: [:portfolio_viewer, :seeker, :holder, :admin],
    creatable_by: [:holder, :editor, :admin]

  #=== FIELD POLICIES ===#

  ADMIN_FIELD = { visible_to: :all_roles, editable_by: [:admin] }
  PUBLIC_ADMIN_FIELD = { visible_to: :everyone, editable_by: [:admin] }
  EDITOR_FIELD = { visible_to: :all_roles, editable_by: [:editor] }
  READ_ONLY_FIELD = { visible_to: :all_roles, editable_by: :nobody }

  field :url_with_caps,                 PUBLIC_ADMIN_FIELD
  field :visibility,                    ADMIN_FIELD
  
  field :name,                          EDITOR_FIELD
  field :summary,                       EDITOR_FIELD
  field :image_url,                     EDITOR_FIELD

  field :validation_request_count,      READ_ONLY_FIELD
  field :learner_count,                 READ_ONLY_FIELD
  field :expert_count,                  READ_ONLY_FIELD
  field :image_medium_url,              READ_ONLY_FIELD
  field :image_small_url,               READ_ONLY_FIELD
  
  #=== ROLE DEFINITIONS ===#


  # This is only intended to capture the edge cases where someone is not a badge expert/learner or group admin but can still view
  role :viewer do |current_user, badge|
    next true if badge.visibility == 'public'
    
    if current_user.present?
      next true if (badge.visibility == 'private') && current_user.member_of?(badge.group_id)
    end
  
    next false
  end

  # Returns true if the current user is allowed to see the group member list AND the badge container itself
  # This is only intended to capture the edge cases where someone is not a badge expert/learner or group admin but can still view.
  # The group member visibility controls whether child badges are allowed to expose portfolio lists
  # NOTE: This is a little confusing... Why consider visbility of members and not admins? But it's easier this way to avoid crazy complex
  #   queries where we are checking at the log level for users who are admins vs members. For now that is overkill.
  role :portfolio_viewer do |current_user, badge, policy|
    policy.is_viewer? && (
      (current_user.present? && current_user.member_of?(badge.group_id)) \
      || (badge.group.member_visibility == 'public')
    )
  end
  
  role :seeker do |current_user, badge|
    current_user.present? && current_user.learner_of?(badge)
  end
  
  role :holder do |current_user, badge|
    current_user.present? && current_user.expert_of?(badge)
  end
  
  role :awarder do |current_user, badge|
    current_user.present? && (
      current_user.admin_of?(badge.group_id) \
      || ((badge.awardability == 'experts') && current_user.expert_of?(badge))
    )
  end
  
  role :editor do |current_user, badge|
    current_user.present? && (
      current_user.admin_of?(badge.group_id) \
      || ((badge.editability == 'experts') && current_user.expert_of?(badge))
    )
  end
  
  role :admin do |current_user, badge|
    current_user.present? && (
      current_user.admin_of?(badge.group_id) \
      || (current_user.id == badge.creator_id)
    )
  end
  
  #=== FEATURE DEFINITIONS ===#

  feature :bulk_tools do |badge|
    badge.group.has? :bulk_tools
  end

  #=== SCOPES ===#

  # Limits a group badge scope (one built from group.badges) to only the badges a particular user has access to in that group
  class GroupScope < ApplicationPolicy::Scope
    attr_reader :current_user, :scope, :group

    def initialize(current_user, scope, group)
      @current_user = current_user
      @scope = scope
      @group = group
    end

    def resolve
      if @current_user.present? && (@current_user.admin || @current_user.admin_of?(@group))
        return @scope.all
      elsif @current_user.present? && @current_user.member_of?(@group)
        return @scope.any_of(
          {:visibility.ne => 'hidden'}, 
          {:id.in => @current_user.all_badge_ids}
        )
      else
        return @scope.where(visibility: 'public')
      end
    end
  end

end