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

  #=== CLASS METHODS ===#

  def self.find(params)
    return self.new(App.find(params))
  end

  #=== INSTANCE METHODS ===#

  # Returns true if there is a membership record for the specified group.
  # In the case of users, this only checks for the membership, not the membership type.
  # Will always return false if there is no membership record, even if the user is the proxy_user or owner.
  # 
  # Accepted item types: user, user change decorator, user id/string
  # Accepted membership_status values: :active, :pending, :disabled, :admin, :member, :any
  def has_user_membership?(item, membership_status = :active)
    return false if item.nil?

    if item.class.to_s.starts_with? 'User'
      this_user_id = item.id
    elsif item.class.to_s == 'BSON::ObjectId'
      this_user_id = item
    elsif item.class.to_s == 'String'
      this_user_id = BSON::ObjectId.from_string(item)
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
  # NOTE: It is most query efficient to pass the full user record.
  def has_admin?(item)
    return false if item.nil?

    if item.class.to_s.starts_with? 'User'
      this_user_id = item.id
      this_user = item
    elsif item.class.to_s == 'BSON::ObjectId'
      this_user_id = item
    elsif item.class.to_s == 'String'
      this_user_id = BSON::ObjectId.from_string(item)
    else
      raise ArgumentError.new("Invalid type #{item.class.to_s} for item. (Accepted types are User, ObjectId or String.)")
    end
    
    return true if admin_user_ids.include?(this_user_id) || (owner_id == this_user_id)

    # We try to save a query for the proxy user. If we have the full user we can test without querying the app for the proxy user.
    if this_user.present?
      return (this_user.type == 'app') && (this_user.proxy_app_id == self.id)
    else
      return proxy_user.id == this_user_id
    end
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
  # Returns decorated version of the app user membership record which has an overridden `save` method.
  def create_user_membership(member_user, creator_user, type: 'member')
    raise ArgumentError.new('Membership record already exists for that user') if has_user_membership? member_user, :any
    raise ArgumentError.new('Only individual users can be members of apps') if member_user.type != 'individual'
    
    user_membership = UserMembershipDecorator.new(
      AppUserMembership.new(
        app: self, 
        user: member_user, 
        creator: creator_user,
        type: type,
      ),
      self
    )
    
    user_membership.save_as(creator_user)

    return user_membership
  end

  # Pass a newly created, updated or destroyed user membership and this method updates the user relations which mirror the memberships.
  def update_user_relations_with(user_membership, current_user)
    user = user_membership.user # shortcut

    if user_membership.active? && !user_membership.destroyed?
      self.users << user unless users.include?(user)
    else
      self.users.delete(user) if users.include?(user)
    end

    if user_membership.pending? && !user_membership.destroyed?
      self.pending_users << user unless pending_users.include?(user)
    else
      self.pending_users.delete(user) if pending_users.include?(user)
    end

    if user_membership.member? && !user_membership.destroyed?
      self.member_users << user unless member_users.include?(user)
    else
      self.member_users.delete(user) if member_users.include?(user)
    end

    if user_membership.admin? && !user_membership.destroyed?
      self.admin_users << user unless admin_users.include?(user)
    else
      self.admin_users.delete(user) if admin_users.include?(user)
    end

    if user_membership.disabled? && !user_membership.destroyed?
      self.disabled_users << user unless disabled_users.include?(user)
    else
      self.disabled_users.delete(user) if disabled_users.include?(user)
    end

    self.save_as(current_user) if self.changed?
    true
  end

  #=== USER MEMBERSHIP DECORATOR INNER CLASS ===#

  class UserMembershipDecorator < SimpleDelegator

    attr_accessor :parent_app

    #=== CLASS METHODS ===#

    def self.find(params)
      return self.new(AppUserMembership.find(params))
    end

    #=== INSTANCE METHODS ===#

    def initialize(user_membership, decorated_parent_app = nil)
      super(user_membership)
      
      @parent_app = decorated_parent_app || AppUserMembershipDecorator.new(user_membership.app)
    end

    def save
      raise ArgumentError.new('You must use save_as to save this item')
    end

    def save_as(current_user)
      return false if !super(current_user)

      @parent_app.update_user_relations_with self, current_user
    end

    def save_as!(current_user)
      super(current_user)

      @parent_app.update_user_relations_with self, current_user
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

      @parent_app.update_user_relations_with self, current_user
    end

  end

end