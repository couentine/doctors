class PortfolioPolicy < ApplicationPolicy

  #=== ACTION POLICIES ===#

  standard_actions :portfolio,
    show_roles: :all_roles,
    update_roles: [:owner, :admin],
    destroy_roles: [:owner]  

  #=== RELATIONSHIP POLICIES ===#

  belongs_to :user,
    via: :user_id,
    visible_to: :all_roles,
    creation_role: :owner

  belongs_to :badge,
    via: :badge_id,
    visible_to: :all_roles,
    creation_role: :viewer

  #=== FIELD POLICIES ===#

  ADMIN_FIELD = { visible_to: :everyone, editable_by: [:admin] }
  OWNER_FIELD = { visible_to: :all_roles, editable_by: [:owner] }
  READ_ONLY_FIELD = { visible_to: :all_roles, editable_by: :nobody }

  field :retracted,                               ADMIN_FIELD

  field :wiki,                                    OWNER_FIELD
  field :show_on_badge,                           OWNER_FIELD
  field :show_on_profile,                         OWNER_FIELD
  field :receive_validation_request_emails,       OWNER_FIELD

  field :status,                                  READ_ONLY_FIELD
  field :user_name,                               READ_ONLY_FIELD
  field :user_username_with_caps,                 READ_ONLY_FIELD
  field :date_started,                            READ_ONLY_FIELD
  field :date_requested,                          READ_ONLY_FIELD
  field :date_withdrawn,                          READ_ONLY_FIELD
  field :date_issued,                             READ_ONLY_FIELD
  field :date_retracted,                          READ_ONLY_FIELD
  field :date_originally_issued,                  READ_ONLY_FIELD

  #=== ROLE DEFINITIONS ===#

  # If the user can see the badge then they can see the portfolio container
  role :viewer do |current_user, log, policy|
    badge = policy.expose[:badge] || log.badge

    next true if badge.visibility == 'public'

    if current_user.present?
      next true if current_user.learner_or_expert_of? log.badge_id
      next true if (badge.visibility == 'private') && current_user.member_of?(badge.group_id)
    end
    
    next false
  end
  
  role :owner do |current_user, log|
    current_user.present? && (current_user.id == log.user_id)
  end
  
  role :admin do |current_user, log, policy|
    badge = policy.expose[:badge] || log.badge

    current_user.present? && current_user.admin_of?(badge.group_id)
  end

  #=== SCOPES ===#

  # Limits a badge portfolio scope (one built from badge.logs) to only the logs which haven't been hidden from the badge members list.
  # NOTE: Raises a standard error if the user doesn't have permission to see the badge portfolios index.
  class BadgeScope < ApplicationPolicy::Scope
    attr_reader :current_user, :scope, :badge

    def initialize(current_user, scope, badge)
      @current_user = current_user
      @scope = scope
      @badge = badge
    end

    def resolve
      @badge_policy = Pundit.policy(@current_user, @badge)

      raise StandardError.new('You do not have permission to see the portfolios for this badge') if (!@badge_policy.can_see_portfolios?)

      if @badge_policy.is_awarder?
        return @scope.all
      elsif @current_user.present?
        return @scope.any_of({
          show_on_badge: true,
          user_id: @current_user.id
        })
      else
        return @scope.where(show_on_badge: true)
      end
    end
  end

  # Limits a user portfolio scope (one built from user.logs) to only the logs which are visible to the current user.
  # This starts by using GroupPolicy::UserScope to filter out any badges which are in non-visible groups.
  # Then the scope further limits to only logs which have show_on_profile set to true.
  # NOTE: Raises a standard error if the user doesn't have permission to see the user portfolios index.
  class UserScope < ApplicationPolicy::Scope
    attr_reader :current_user, :scope, :target_user

    def initialize(current_user, scope, target_user)
      @current_user = current_user
      @scope = scope
      @target_user = target_user
    end

    def resolve
      @target_user_policy = Pundit.policy(@current_user, @target_user)

      if (!@target_user_policy.can_see_portfolios?)
        raise StandardError.new('You do not have permission to see the portfolios for this target_user') 
      end

      if (@current_user == @target_user) || (@current_user.present? && @current_user.admin)
        return @scope.all
      else
        # First use the group policy to determine which of the target user's groups are visible to the current user
        all_visible_group_ids = GroupPolicy::UserScope.new(@current_user, 'all', @target_user).resolve.pluck(:id)

        # Next query for all of the badges which this current user can see
        if @current_user.present?
          all_visible_badge_ids = Badge.where(:group_id.in => all_visible_group_ids).any_of(
            { visibility: 'public' },
            { :id.in => @current_user.all_badge_ids },
            { :group_id.in => @current_user.admin_of_ids },
            { visibility: 'private', :group_id.in => @current_user.member_of_ids }
          ).pluck(:id)
        else
          all_visible_badge_ids = Badge.where(:group_id.in => all_visible_group_ids, visibility: 'public').pluck(:id)
        end

        # Finally we build the return scope by limiting it to those specific badges and only those which are visible on the profile
        if @current_user.present?
          return @scope.where(:badge_id.in => all_visible_badge_ids).any_of(
            { show_on_badge: true },
            { user_id: @current_user.id }
          )
        else
          return @scope.where(:badge_id.in => all_visible_badge_ids, show_on_badge: true)
        end
      end
    end
  end

end