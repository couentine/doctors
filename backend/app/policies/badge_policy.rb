class BadgePolicy < ApplicationPolicy
  attr_reader :current_user, :badge, :badges

  def initialize(current_user, badge_or_badges)
    @current_user = current_user
    if (badge_or_badges.class == Mongoid::Criteria)
      @badges = badge_or_badges
      @records = badge_or_badges
    else
      @badge = badge_or_badges
      @record = badge_or_badges
    end
  end

  #=== ACTION POLICIES ===#

  # Only available to authenticated users
  def index?
    return @current_user.present? \
      && @current_user.has?('all:index') \
      && @current_user.has?('badges:read') \
      && @current_user.has?('current_user:read')
  end

  def show?
    # All badges are shown, but fields are conditionally displayed based on `show_all_fields?`
    return @current_user.has?('badges:read')
  end

  def edit?
    if @current_user.present? && @current_user.has?('badges:write')
      return true if @current_user.admin?
      return true if @current_user.admin_of?(@badge.group_id)
      return true if (@badge.editability == 'experts') && @current_user.expert_of?(@badge)
    end

    return false
  end
  
  def award?
    return @current_user.has?('portfolios:review') && is_awarder?
  end
  
  def bulk_award?
    return award? && @badge.group.has?(:bulk_tools)
  end
  
  #=== FILTER POLICIES ===#
  
  def show_all_fields?
    return true if @badge.visibility == 'public'
    
    if @current_user.present?
      return true if @current_user.admin?
      return true if @current_user.admin_of? @badge.group_id
      return true if @current_user.learner_or_expert_of?(@badge)
      return true if (@badge.visibility == 'private') && @current_user.member_of?(@badge.group_id)
    end
  
    return false
  end

  # Returns true if the current user is allowed to see both the details of the badge and the members list of the group
  def show_people?
    return false if !show_all_fields?
    
    # The group member visibility controls whether child badges are allowed to expose portfolio lists
    # NOTE: This is a little confusing... Why consider visbiility of members and not admins? But it's easier this way to avoid crazy complex
    #   queries where we are checking at the log level for users who are admins vs members. For now that is overkill.
    return Pundit.policy(@current_user, @badge.group).show_members?
  end
  
  # This differs from the award? policy because it just checks that the user *can* award, not that the token has the award permission.
  def is_awarder?
    if @current_user.present?
      return true if @current_user.admin?
      return true if @current_user.admin_of?(@badge.group_id)
      return true if (@badge.awardability == 'experts') && @current_user.expert_of?(@badge)
    end

    return false
  end

  #=== RELATIONSHIP POLICIES ===#

  def portfolios_index?
    return @current_user.has?('all:index') \
      && @current_user.has?('badges:read') \
      && @current_user.has?('portfolios:read') \
      && show_people?
  end

  #=== USER-FACING METADATA ===#
  
  def meta
    return {
      current_user: {
        can_see_record: show_all_fields?,
        can_edit_record: edit?,
        can_award_record: award?,
        is_seeker: @current_user.present? && @current_user.learner_of?(@badge),
        is_holder: @current_user.present? && @current_user.expert_of?(@badge)
      }
    }
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