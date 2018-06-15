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

  # Queries the live count of active user memberships from the DB.
  def calculate_user_count
    return user_memberships.where(status: 'active').count
  end

  # Returns true if there is a membership record for the specified user. This only checks for the membership, not the membership type.
  # Will always return false if there is no membership record, even if the user is the proxy_user or owner.
  # 
  # Accepted membership_status values: :active, :pending, :disabled, :admin, :member, :any
  def has_user_membership?(user, membership_status = :active)
    return false if !user.present? # if changing this line remember that adding user decorators to nil prevents them from evaluating as nil

    case membership_status.to_sym
    when :active
      relevant_app_ids = user.app_ids
    when :admin
      relevant_app_ids = user.admin_app_ids
    when :member
      relevant_app_ids = user.member_app_ids
    when :pending
      relevant_app_ids = user.pending_app_ids
    when :disabled
      relevant_app_ids = user.disabled_app_ids
    else
      relevant_app_ids = (user.app_ids + user.pending_app_ids + user.disabled_app_ids)
    end

    return relevant_app_ids.include? self.id
  end

  # Returns true if the specified user is an admin or the owner user or the proxy user.
  # NOTE: Differs from `has_user_membership?` because it returns true even if there is no membership record for the user.
  def has_admin?(user)
    return false if !user.present? # if changing this line remember that adding user decorators to nil prevents them from evaluating as nil
    return true if owner_id == user.id
    return true if (user.type == 'app') && (user.proxy_app_id == self.id)
    return user.admin_app_ids.include? self.id
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
      unless user.app_ids.include?(id)
        user.app_ids << id
        self.user_count += 1
      end
    else
      if user.app_ids.include?(id)
        user.app_ids.delete(id)
        self.user_count -= 1
      end
    end

    if user_membership.pending? && !user_membership.destroyed?
      user.pending_app_ids << id unless user.pending_app_ids.include?(id)
    else
      user.pending_app_ids.delete(id) if user.pending_app_ids.include?(id)
    end

    if user_membership.member? && !user_membership.destroyed?
      user.member_app_ids << id unless user.member_app_ids.include?(id)
    else
      user.member_app_ids.delete(id) if user.member_app_ids.include?(id)
    end

    if user_membership.admin? && !user_membership.destroyed?
      user.admin_app_ids << id unless user.admin_app_ids.include?(id)
    else
      user.admin_app_ids.delete(id) if user.admin_app_ids.include?(id)
    end

    if user_membership.disabled? && !user_membership.destroyed?
      user.disabled_app_ids << id unless user.disabled_app_ids.include?(id)
    else
      user.disabled_app_ids.delete(id) if user.disabled_app_ids.include?(id)
    end

    user.save if user.changed?
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