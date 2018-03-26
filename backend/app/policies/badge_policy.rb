class BadgePolicy < ApplicationPolicy
  attr_reader :user, :badge, :badges

  def initialize(user, badge_or_badges)
    @user = user
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
    return @user.present? && @user.has?('badges:read')
  end

  def show?
    # All badges are shown, but fields are conditionally displayed based on `show_all_fields?`
    true
  end

  def edit?
    if @user.present? && @user.has?('badges:write')
      return true if @user.admin?
      return true if @user.admin_of?(@badge.group_id)
      return true if (@badge.editability == 'experts') && @user.expert_of?(@badge)
    end

    return false
  end
  
  def award?
    if @user.present? && @user.has?('portfolios:review')
      return true if @user.admin?
      return true if @user.admin_of?(@badge.group_id)
      return true if (@badge.awardability == 'experts') && @user.expert_of?(@badge)
    end

    return false
  end
  
  #=== FILTER POLICIES ===#
  
  def show_all_fields?
    return true if @badge.visibility == 'public'
    
    if @user.present? && @user.has?('badges:read')
      return true if @user.admin?
      return true if @user.admin_of? @badge.group_id
      return true if @user.learner_or_expert_of?(@badge)
      return true if (@badge.visibility == 'private') && @user.member_of?(@badge.group_id)
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
        is_seeker: @user.present? && @user.learner_of?(@badge),
        is_holder: @user.present? && @user.expert_of?(@badge)
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