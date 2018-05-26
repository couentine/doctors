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

  # Only available to authenticated users
  def index?
    return @current_user.present? \
      && @current_user.has?('all:index') \
      && @current_user.has?('groups:read') \
      && @current_user.has?('current_user:read')
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
    if @current_user.present?
      return true if @current_user.admin?
      return true if @current_user.admin_of?(@group)
      return true if (@group.member_visibility == 'private') && @current_user.member_of?(@group)
    end
    
    return false
  end
  
  def show_admins?
    return true if @group.admin_visibility == 'public'
    if @current_user.present?
      return true if @current_user.admin?
      return true if @current_user.admin_of?(@group)
      return true if (@group.admin_visibility == 'private') && @current_user.member_of?(@group)
    end
    
    return false
  end
  
  def show_group_tags?
    return true if @group.tag_visibility == 'public'
    if @current_user.present?
      return true if @current_user.admin?
      return true if @current_user.admin_of?(@group)
      return true if (@group.tag_visibility == 'members') && @current_user.member_of?(@group)
    end

    return false
  end

  #=== RELATIONSHIP POLICIES ===#

  def badges_index?
    # There is no action-level restriction on the badges index. The individual badges are filtered by visibility.
    return @current_user.has?('all:index') \
      && @current_user.has?('groups:read') \
      && @current_user.has?('badges:read')
  end

  # This authorizes whether the user can see a list of users who are members
  def members_index?
    return @current_user.has?('all:index') \
      && @current_user.has?('groups:read') \
      && @current_user.has?('users:read') \
      && show_members?
  end

  # This authorizes whether the user can see a list of users who are admins
  def admins_index?
    return @current_user.has?('all:index') \
      && @current_user.has?('groups:read') \
      && @current_user.has?('users:read') \
      && show_admins?
  end

  # This authorizes whether the user can see a list of users who are members AND admins
  def members_and_admins_index?
    return @current_user.has?('all:index') \
      && @current_user.has?('groups:read') \
      && @current_user.has?('users:read') \
      && show_members? \
      && show_admins?
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