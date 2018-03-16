class GroupPolicy < ApplicationPolicy
  attr_reader :user, :group, :groups

  def initialize(user, group_or_groups)
    @user = user
    if (group_or_groups.class == Mongoid::Criteria)
      @groups = group_or_groups
      @records = group_or_groups
    else
      @group = group_or_groups
      @record = group_or_groups
    end
  end

  #=== ACTION POLICIES ===#

  def index?
    return @user.present? && @user.has?('groups:read')
  end

  def show?
    true # All groups and fields are shown, but relationships are conditionally displayed based on filters below
  end

  def edit?
    if @user.present? && @user.has?('groups:write')
      return true if @user.admin?
      return true if @user.id == @group.owner_id
    end
    
    return false
  end

  #=== FILTER POLICIES ===#
  
  def show_members?
    return true if @group.member_visibility == 'public'
    if @user.present? && @user.has?('groups:read')
      return true if @user.admin?
      return true if @user.admin_of?(@group)
      return true if (@group.member_visibility == 'private') && @user.member_of?(@group)
    end
    
    return false
  end
  
  def show_admins?
    return true if @group.admin_visibility == 'public'
    if @user.present? && @user.has?('groups:read')
      return true if @user.admin?
      return true if @user.admin_of?(@group)
      return true if (@group.admin_visibility == 'private') && @user.member_of?(@group)
    end
    
    return false
  end
  
  def show_group_tags?
    return true if @group.tag_visibility == 'public'
    if @user.present? && @user.has?('groups:read')
      return true if @user.admin?
      return true if @user.admin_of?(@group)
      return true if (@group.tag_visibility == 'members') && @user.member_of?(@group)
    end

    return false
  end

  #=== RELATIONSHIP ACTION POLICIES ===#

  def copy_badges?
    return true if @group.badge_copyability == 'public'
    if @user.present? && @user.has?('groups:read', 'badges:read', 'badges:write')
      return true if @user.admin?
      return true if @user.admin_of?(@group)
      return true if (@group.badge_copyability == 'members') && @user.member_of?(@group)
    end

    return false
  end

  def assign_group_tags?
    if @user.present? && @user.has?('group_tags:write')
      return true if @user.admin?
      return true if @user.admin_of?(@group)
      return true if (@group.tag_assignability == 'members') && @user.member_of?(@group)
    end
    
    return false
  end

  def create_group_tags?
    if @user.present? && @user.has?('group_tags:write')
      return true if @user.admin?
      return true if @user.admin_of?(@group)
      return true if (@group.tag_creatability == 'members') && @user.member_of?(@group)
    end
    
    return false
  end

  #=== USER-FACING METADATA ===#
  
  def meta
    return {
      current_user: {
        can_see_record: show?,
        can_edit_record: edit?,
        can_see_members: show_members?,
        can_see_admins: show_admins?,
        can_see_group_tags: show_group_tags?,
        can_copy_badges: copy_badges?,
        can_assign_group_tags: assign_group_tags?,
        can_create_group_tags: create_group_tags?,
        is_member: @user.present? && @user.member_of?(@group),
        is_admin: @user.present? && @user.admin_of?(@group)
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