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

  def index?
    return @current_user.present? && @current_user.has?('badges:read')
  end

  def show?
    # All badges are shown, but fields are conditionally displayed based on `show_all_fields?`
    true
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
    if @current_user.present? && @current_user.has?('portfolios:review')
      return true if @current_user.admin?
      return true if @current_user.admin_of?(@badge.group_id)
      return true if (@badge.awardability == 'experts') && @current_user.expert_of?(@badge)
    end

    return false
  end
  
  #=== FILTER POLICIES ===#
  
  def show_all_fields?
    return true if @badge.visibility == 'public'
    
    if @current_user.present? && @current_user.has?('badges:read')
      return true if @current_user.admin?
      return true if @current_user.admin_of? @badge.group_id
      return true if @current_user.learner_or_expert_of?(@badge)
      return true if (@badge.visibility == 'private') && @current_user.member_of?(@badge.group_id)
    end
  
    return false
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

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end

end