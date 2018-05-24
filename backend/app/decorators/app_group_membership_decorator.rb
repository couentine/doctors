#==========================================================================================================================================#
# 
# APP GROUP MEMBERSHIP DECORATOR
# 
# Use this decorator to add / remove / manage member groups.
# 
# ## Example Usage ##
# 
# ```
# app = AppGroupMembershipDecorator.new(App.find('example-app'))
# 
# if !app.has_group_membership? new_member_group, :any
#   new_group_membership = app.create_group_membership(new_member_group, creator_user)
# end
# ```
# 
#==========================================================================================================================================#

class AppGroupMembershipDecorator < SimpleDelegator

  #=== INSTANCE METHODS ===#

  # Returns true if there is a membership record for the specified group.
  # 
  # Accepted item types: group, group change decorator, group id/string
  # Accepted membership_status values: :active, :pending, :disabled, :any
  def has_group_membership?(item, membership_status = :active)
    item = BSON::ObjectId.from_string(item) if item.class.to_s == String

    case item.class.to_s
    when 'Group', 'GroupChangeDecorator'
      this_group_id = item.id
    when 'BSON::ObjectId'
      this_group_id = item
    else
      raise ArgumentError.new("Invalid type #{item.class.to_s} for item. (Accepted types are Group, ObjectId or String.)")
    end

    case membership_status.to_s
    when 'active'
      relevant_group_ids = group_ids
    when 'pending'
      relevant_group_ids = pending_group_ids
    when 'disabled'
      relevant_group_ids = disabled_group_ids
    else
      relevant_group_ids = (group_ids + pending_group_ids + disabled_group_ids).uniq
    end

    return relevant_group_ids.include? this_group_id
  end

  # Returns the group membership of the specified group or nil if none is present
  # Optionally include a `membership_status` value to filter by status.
  # 
  # Accepted membership_status values: :active, :pending, :disabled, :any
  # 
  # Returns decorated version of the app group membership record which has an overridden `save` method.
  def get_group_membership(group, membership_status = :any)
    # Avoid a query if possible
    if has_group_membership? group, membership_status
      return GroupMembershipDecorator.new(group_memberships.where(group: group).first, self)
    else
      return nil
    end
  end

  # Creates a new membership for the specified `member_group` if one does not already exist.
  # Raises an ArgumentError if there is already a membership.
  # 
  # If `creator_user` is an admin of `member_group` then `group_approval_status` is set to approved.
  # If `creator_user` is an admin of the app, then `app_approval_status` is set to approved.
  # If this is a MANDATORY_APP then both approval stati are set to approved.
  # 
  # Returns decorated version of the app group membership record which has an overridden `save` method.
  def create_group_membership(member_group, creator_user)
    raise ArgumentError.new('Membership record already exists for that group') if has_group_membership? member_group, :any
    
    group_membership = GroupMembershipDecorator.new(
      AppGroupMembership.new(
        app: self, 
        group: member_group, 
        creator: creator_user,
      ),
      self
    )

    app = AppUserMembershipDecorator.new(self)
    if mandatory? || app.has_admin?(creator_user)
      group_membership.app_approval_status = 'approved'
    end
    if mandatory? || member_group.has_admin?(creator_user)
      group_membership.group_approval_status = 'approved'
    end
    
    group_membership.save_as(creator_user)

    return group_membership
  end

  # Pass a newly created or updated group membership and this method updates the group relations which mirror the memberships.
  def update_group_relations_with(group_membership, current_user)
    group = group_membership.group # shortcut

    if group_membership.active?
      self.groups << group unless groups.include?(group)
    else
      self.groups.delete(group) if groups.include?(group)
    end

    if group_membership.pending?
      self.pending_groups << group unless pending_groups.include?(group)
    else
      self.pending_groups.delete(group) if pending_groups.include?(group)
    end

    if group_membership.disabled?
      self.disabled_groups << group unless disabled_groups.include?(group)
    else
      self.disabled_groups.delete(group) if disabled_groups.include?(group)
    end

    self.save_as(current_user) if self.changed?
    true
  end

  # === GROUP MEMBERSHIP DECORATOR INNER CLASS === #

  class GroupMembershipDecorator < SimpleDelegator

    attr_accessor :parent_app

    def initialize(group_membership, decorated_parent_app)
      super(group_membership)
      
      @parent_app = decorated_parent_app
    end

    def save_as(current_user)
      return false if !super(current_user)

      @parent_app.update_group_relations_with self, current_user
    end

    def save_as!(current_user)
      super(current_user)!

      @parent_app.update_group_relations_with self, current_user
    end

  end

end