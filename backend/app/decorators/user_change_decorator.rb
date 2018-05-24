#==========================================================================================================================================#
# 
# USER CHANGE DECORATOR
# 
# Eventually this will be the default decorator to try whenever you need to modify a user. (Create, update or destroy.)
# But for now you can only use it to create new users. You should only create new users using this decorator.
# NOTE: This is only for INDIVIDUAL users, not proxy users (yet).
# 
# ## Example Usage ##
# 
# ```
# user = UserChangeDecorator.new(User.new(name: 'Example User'))
# user.save
# ```
# 
#==========================================================================================================================================#

class UserChangeDecorator < SimpleDelegator

  def save!
    raise ArgumentError.new('The bang method is not yet enabled for this decorator')
  end

  def save
    raise ArgumentError.new('You can only use this decorator to create new users') if !self.new_record?
    
    # Create the user
    return false if !super
    
    # Now add the user as a member to the Badge List standard app
    app = AppUserMembershipDecorator.new(App.find('badgelist'))
    app.create_user_membership(self, app.proxy_user)

    return true
  end

end