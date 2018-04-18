class GroupPolicy < ApplicationPolicy
  attr_reader :current_user, :group, :groups

  def initialize(current_user, group_or_groups)
    @current_user = current_user
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
    return @current_user.present? && @current_user.has?('groups:read')
  end

  def show?
    # All groups and fields are shown, but relationships are conditionally displayed based on filters below
    return @current_user.has?('groups:read')
  end

  def edit?
    if @current_user.present? && @current_user.has?('groups:write')
      return true if @current_user.admin?
      return true if @current_user.id == @group.owner_id
    end
    
    return false
  end

  #=== FILTER POLICIES ===#
  
  def show_members?
    return true if @group.member_visibility == 'public'
    if @current_user.present? && @current_user.has?('groups:read')
      return true if @current_user.admin?
      return true if @current_user.admin_of?(@group)
      return true if (@group.member_visibility == 'private') && @current_user.member_of?(@group)
    end
    
    return false
  end
  
  def show_admins?
    return true if @group.admin_visibility == 'public'
    if @current_user.present? && @current_user.has?('groups:read')
      return true if @current_user.admin?
      return true if @current_user.admin_of?(@group)
      return true if (@group.admin_visibility == 'private') && @current_user.member_of?(@group)
    end
    
    return false
  end
  
  def show_group_tags?
    return true if @group.tag_visibility == 'public'
    if @current_user.present? && @current_user.has?('groups:read')
      return true if @current_user.admin?
      return true if @current_user.admin_of?(@group)
      return true if (@group.tag_visibility == 'members') && @current_user.member_of?(@group)
    end

    return false
  end

  #=== RELATIONSHIP ACTION POLICIES ===#

  def badges_index?
    # There is no action-level restriction on the badges index. The individual badges are filtered by visibility.
    return @current_user.has?('groups:read') && @current_user.has?('badges:read')
  end

  # This authorizes whether the user can see a list of users who are members
  def members_index?
    return @current_user.has?('groups:read') && @current_user.has?('users:read') && show_members?
  end

  # This authorizes whether the user can see a list of users who are admins
  def admins_index?
    return @current_user.has?('groups:read') && @current_user.has?('users:read') && show_admins?
  end

  # This authorizes whether the user can see a list of users who are members AND admins
  def members_and_admins_index?
    return @current_user.has?('groups:read') && @current_user.has?('users:read') && show_members? && show_admins?
  end

  def copy_badges?
    return true if @group.badge_copyability == 'public'
    if @current_user.present? && @current_user.has?('groups:read', 'badges:read', 'badges:write')
      return true if @current_user.admin?
      return true if @current_user.admin_of?(@group)
      return true if (@group.badge_copyability == 'members') && @current_user.member_of?(@group)
    end

    return false
  end

  def assign_group_tags?
    if @current_user.present? && @current_user.has?('group_tags:write')
      return true if @current_user.admin?
      return true if @current_user.admin_of?(@group)
      return true if (@group.tag_assignability == 'members') && @current_user.member_of?(@group)
    end
    
    return false
  end

  def create_group_tags?
    if @current_user.present? && @current_user.has?('group_tags:write')
      return true if @current_user.admin?
      return true if @current_user.admin_of?(@group)
      return true if (@group.tag_creatability == 'members') && @current_user.member_of?(@group)
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
        is_member: @current_user.present? && @current_user.member_of?(@group),
        is_admin: @current_user.present? && @current_user.admin_of?(@group)
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