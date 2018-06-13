#==========================================================================================================================================#
# 
# APP CHANGE DECORATOR
# 
# This is default decorator to try whenever you need to modify an app. (Create, update or destroy.)
# It detects any changes which will effect other records in the database.
# If those changes are basic (and easy to detect without lots of queries and CPU cycles), then this decorator will do them right away. 
# If those changes are more involved then this decorator will raise an error with instructions on which other decorator to use.
# 
# ## Example Usage ##
# 
# ```
# app = AppChangeDecorator.new(App.new(owner: user1))
# app.save_as(current_user)
# app.owner = user2
# app.save_as(current_user)
# app.destroy
# ```
# 
#==========================================================================================================================================#

class AppChangeDecorator < SimpleDelegator

  #=== CLASS METHODS ===#

  def self.find(params)
    return self.new(App.find(params))
  end
  
  #=== INSTANCE METHODS ===#

  # In addition to the normal validations, you must set `owner` in order to use this method.
  def save_as(current_user)
    was_new_record = self.new_record?
    proxy_user_needs_update = name_changed? || slug_changed?

    if owner.nil?
      self.errors.add(:owner_id, 'cannot be blank')
      return false
    elsif !super(current_user)
      return false
    end
    
    # Create / update the proxy user if needed
    if proxy_user.blank?
      self.proxy_user = User.new
      self.proxy_user.type = 'app'

      self.proxy_user.skip_confirmation!
      self.proxy_user.skip_reconfirmation!

      if !self.proxy_user.save
        self.errors.add(:proxy_user, 'could not be created')
        self.delete if was_new_record && !self.new_record?
        return false
      end
    elsif proxy_user_needs_update
      proxy_user.skip_reconfirmation! # changes to email won't require confirmation
      if !proxy_user.save # this will automatically refresh the fields
        self.errors.add(:proxy_user, 'could not be updated')
        self.delete if was_new_record && !self.new_record?
        return false
      end
    end

    # Add the owner as an admin member if needed
    # Try to avoid hitting the database unless it's necessary
    app = AppUserMembershipDecorator.new(self)
    if !app.has_user_membership?(owner, :any)
      # There's no membership record at all, create one
      user_membership = app.create_user_membership(owner, owner, type: 'admin') rescue nil

      if !user_membership || !user_membership.errors.blank?
        self.errors.add(:base, 'Owner user membership could not be created')
        self.delete if was_new_record && !self.new_record?
        return false
      end
    elsif !app.has_user_membership?(owner, :admin)
      # There *is* a membership record but it isn't an admin one, so upgrade it
      user_membership = app.get_user_membership(owner)
      user_membership.type = 'admin'
      
      if !user_membership.save_as(current_user)
        self.errors.add(:base, 'Existing owner user membership could not be upgraded to admin')
        self.delete if was_new_record && !self.new_record?
        return false
      end
    end

    true
  end

  def destroy
    super

    # For now there's nothing else to do, but eventually there may be
  end

end