#==========================================================================================================================================#
# 
# APP USER MEMBERSHIP DECORATOR
# 
# Use this decorator to add / remove / manage member users.
# 
# ## Example Usage ##
# 
# ```
# app = AppUserMembershipDecorator.new(App.find('example-app'))
# 
# if !app.has_user_membership? new_member_user, :any
#   new_user_membership = app.create_user_membership(new_member_user, creator_user)
# end
# ```
# 
#==========================================================================================================================================#

class AppUserMembershipDecorator < SimpleDelegator

  #=== INSTANCE METHODS ===#

  # Returns true if there is a membership record for the specified group.
  # In the case of users, this only checks for the membership, not the membership type.
  # Will always return false if there is no membership record, even if the user is the proxy_user or owner.
  # 
  # Accepted item types: user, user id/string
  # Accepted membership_status values: :active, :pending, :disabled, :admin, :member, :any
  def has_user_membership?(item, membership_status = :active)
    item = BSON::ObjectId.from_string(item) if item.class.to_s == String

    case item.class.to_s
    when 'User'
      this_user_id = item.id
    when 'BSON::ObjectId'
      this_user_id = item
    else
      raise ArgumentError.new("Invalid type #{item.class.to_s} for item. (Accepted types are User, ObjectId or String.)")
    end

    case membership_status.to_s
    when 'active'
      relevant_user_ids = user_ids
    when 'admin'
      relevant_user_ids = admin_user_ids
    when 'member'
      relevant_user_ids = member_user_ids
    when 'pending'
      relevant_user_ids = pending_user_ids
    when 'disabled'
      relevant_user_ids = disabled_user_ids
    else
      relevant_user_ids = (user_ids + pending_user_ids + disabled_user_ids).uniq
    end

    return relevant_user_ids.include? this_user_id
  end

  # Returns true if the specified user is an admin or the owner user or the proxy user.
  # NOTE: Differs from `has_user_membership?` because it returns true even if there is no membership record for the user.
  # 
  # Accepted item types: user, user id/string
  def has_admin?(item)
    case item.class.to_s
    when 'User'
      this_user_id = item.id
    when 'BSON::ObjectId'
      this_user_id = item
    when 'String'
      this_user_id = BSON::ObjectId.from_string(item)
    else
      raise ArgumentError.new("Invalid type #{item.class.to_s} for item. (Accepted types are User, ObjectId or String.)")
    end
    
    return (proxy_user.id == this_user_id) || (owner_id == this_user_id) || admin_user_ids.include?(this_user_id)
  end

  # Returns the user membership of the specified user or nil if none is present
  # Optionally include a `membership_status` value to filter by status.
  # 
  # Accepted membership_status values: :active, :pending, :disabled, :admin, :member, :any
  # 
  # Returns decorated version of the app user membership record which has an overridden `save` method.
  def get_user_membership(user, membership_status = :any)
    # Avoid a query if possible
    if has_user_membership? user, membership_status
      return UserMembershipDecorator.new(user_memberships.where(user: user).first, self)
    else
      return nil
    end
  end

  # Creates a new membership for the specified `member_user` if one does not already exist.
  # Raises an ArgumentError if there is already a membership.
  # 
  # If `creator_user` is same as `member_user` then `user_approval_status` is set to approved.
  # If `creator_user` is an admin of the app, then `app_approval_status` is set to approved.
  # 
  # Returns decorated version of the app user membership record which has an overridden `save` method.
  def create_user_membership(member_user, creator_user, type: 'member')
    raise ArgumentError.new('Membership record already exists for that user') if has_user_membership? member_user, :any
    
    decorated_user_membership = UserMembershipDecorator.new(
      AppUserMembership.new(
        app: self, 
        user: member_user, 
        creator: creator_user,
        type: type,
      ),
      self
    )

    # Scenarios to keep in mind: Initial adding of the owner, admin-adding of a new member, membership request from non-admin
    if has_admin? creator_user
      decorated_user_membership.app_approval_status = 'approved'
    end
    if creator_user == member_user
      decorated_user_membership.user_approval_status = 'approved'
    end
    
    decorated_user_membership.save

    return decorated_user_membership
  end

  # Pass a newly created or updated user membership and this method updates the user relations which mirror the memberships.
  def update_user_relations_with(user_membership)
    user = user_membership.user # shortcut

    if user_membership.active?
      self.users << user unless users.include?(user)
    else
      self.users.delete(user) if users.include?(user)
    end

    if user_membership.pending?
      self.pending_users << user unless pending_users.include?(user)
    else
      self.pending_users.delete(user) if pending_users.include?(user)
    end

    if user_membership.member?
      self.member_users << user unless member_users.include?(user)
    else
      self.member_users.delete(user) if member_users.include?(user)
    end

    if user_membership.admin?
      self.admin_users << user unless admin_users.include?(user)
    else
      self.admin_users.delete(user) if admin_users.include?(user)
    end

    if user_membership.disabled?
      self.disabled_users << user unless disabled_users.include?(user)
    else
      self.disabled_users.delete(user) if disabled_users.include?(user)
    end

    self.save if self.changed?
    true
  end

  # === USER MEMBERSHIP DECORATOR INNER CLASS === #

  class UserMembershipDecorator < SimpleDelegator

    attr_accessor :parent_app

    def initialize(user_membership, decorated_parent_app)
      super(user_membership)
      
      @parent_app = decorated_parent_app
    end

    def save
      return false if !super

      @parent_app.update_user_relations_with self
    end

    def save!
      super

      @parent_app.update_user_relations_with self
    end

  end

end