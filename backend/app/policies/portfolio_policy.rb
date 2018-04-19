class PortfolioPolicy < ApplicationPolicy
  attr_reader :current_user, :log, :logs

  def initialize(current_user, log_or_logs)
    @current_user = current_user
    if (log_or_logs.class == Mongoid::Criteria)
      @logs = log_or_logs
      @records = log_or_logs
    else
      @log = log_or_logs
      @record = log_or_logs
    end
  end

  #=== ACTION POLICIES ===#

  def show?
    return false if !@current_user.has?('portfolios:read')

    # If the user can see the badge then they can see the portfolio container
    return Pundit.policy(@current_user, @log.badge).show_all_fields?
  end

  #=== USER-FACING METADATA ===#
  
  def meta
    return {
      current_user: {
        can_see_record: true # calling show here results in lots of queries in the portfolios index
      }
    }
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

      raise StandardError.new('You do not have permission to see the portfolios for this badge') if (!@badge_policy.portfolios_index?)

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

      if (!@target_user_policy.portfolios_index?)
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