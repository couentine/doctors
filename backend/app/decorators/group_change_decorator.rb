#==========================================================================================================================================#
# 
# GROUP CHANGE DECORATOR
# 
# Eventually this will be the default decorator to try whenever you need to modify a group. (Create, update or destroy.)
# But for now you can only use it to create new groups. You should only create new groups using this decorator.
# 
# ## Example Usage ##
# 
# ```
# group = GroupChangeDecorator.new(Group.new(name: 'Example Group'))
# group.save
# ```
# 
#==========================================================================================================================================#

class GroupChangeDecorator < SimpleDelegator

  def save!
    raise ArgumentError.new('The bang method is not yet enabled for this decorator')
  end

  def save
    raise ArgumentError.new('You can only use this decorator to create new groups') if !self.new_record?
    
    # Create the group
    return false if !super
    
    # Now add the group as a member to the Badge List standard app
    app = AppGroupMembershipDecorator.new(App.find('badgelist'))
    app.create_group_membership(self, app.proxy_user)

    return true
  end

end