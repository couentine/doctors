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

  #=== CLASS METHODS ===#

  def self.find(params)
    return self.new(App.find(params))
  end

  #=== INSTANCE METHODS ===#

  # Queries the live count of active group memberships from the DB.
  def calculate_group_count
    return group_memberships.where(status: 'active').count
  end

  # Returns true if there is a membership record for the specified group.
  # 
  # Accepted membership_status values: :active, :pending, :disabled, :any
  def has_group_membership?(group, membership_status = :active)
    return false if !group.present? # if changing this line remember that adding decorators to nil prevents them from evaluating as nil

    case membership_status.to_s
    when 'active'
      relevant_app_ids = group.app_ids
    when 'pending'
      relevant_app_ids = group.pending_app_ids
    when 'disabled'
      relevant_app_ids = group.disabled_app_ids
    else
      relevant_app_ids = (group.app_ids + group.pending_app_ids + group.disabled_app_ids)
    end

    return relevant_app_ids.include? self.id
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

  # Pass a newly created, updated or destroyed group membership and this method updates the group relations which mirror the memberships.
  def update_group_relations_with(group_membership, current_user)
    group = group_membership.group # shortcut

    if group_membership.active? && !group_membership.destroyed?
      unless group.app_ids.include?(id)
        group.app_ids << id
        self.group_count += 1
      end
    else
      if group.app_ids.include?(id)
        group.app_ids.delete(id)
        self.group_count -= 1
      end
    end

    if group_membership.pending? && !group_membership.destroyed?
      group.pending_app_ids << id unless group.pending_app_ids.include?(id)
    else
      group.pending_app_ids.delete(id) if group.pending_app_ids.include?(id)
    end

    if group_membership.disabled? && !group_membership.destroyed?
      group.disabled_app_ids << id unless group.disabled_app_ids.include?(id)
    else
      group.disabled_app_ids.delete(id) if group.disabled_app_ids.include?(id)
    end

    group.save if group.changed?
    self.save_as(current_user) if self.changed?

    true
  end

  #=== GROUP MEMBERSHIP DECORATOR INNER CLASS ===#

  class GroupMembershipDecorator < SimpleDelegator

    attr_accessor :parent_app

    #=== CLASS METHODS ===#

    def self.find(params)
      return self.new(AppGroupMembership.find(params))
    end

    #=== INSTANCE METHODS ===#

    def initialize(group_membership, decorated_parent_app = nil)
      super(group_membership)
      
      @parent_app = decorated_parent_app || AppGroupMembershipDecorator.new(group_membership.app)
    end

    def save
      raise ArgumentError.new('You must use save_as to save this item')
    end

    def save_as(current_user)
      return false if !super(current_user)

      @parent_app.update_group_relations_with self, current_user
    end

    def save_as!(current_user)
      super(current_user)

      @parent_app.update_group_relations_with self, current_user
    end

    def destroy
      raise ArgumentError.new('You must use destroy_as to destroy this item')
    end

    def destroy_as(current_user)
      if @parent_app.mandatory?
        self.errors.add(:base, 'This app is part of the core Badge List platform, the membership cannot be deleted')
        return false
      end

      return false if !super

      @parent_app.update_group_relations_with(self, current_user)
    end

  end

end