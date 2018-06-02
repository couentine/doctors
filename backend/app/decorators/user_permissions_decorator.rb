class UserPermissionsDecorator < SimpleDelegator

  attr_accessor :api_permissions, :access_method

  def initialize(user, authentication_token = nil, access_method = nil)
    self.access_method = access_method
    unfiltered_permissions = ApplicationPolicy::API_PERMISSIONS.keys
    availability_filter = nil
    
    if authentication_token.present?
      # This request comes from an api user so start with the permission sets from their token.
      unfiltered_permissions = authentication_token.permissions
      
      if user.type == 'group'
        availability_filter = :api_group
      elsif user.type == 'app'
        availability_filter = :api_app
      else
        availability_filter = :api_user
      end
    elsif user.present?
      availability_filter = :web_user
    elsif access_method == :web
      availability_filter = :web_visitor
    else
      availability_filter = :api_visitor
    end

    # Now filter the permission sets by only those which are available based on the current authentication type / access method combo
    self.api_permissions = unfiltered_permissions & (ApplicationPolicy::API_PERMISSIONS.select do |permission, settings|
      settings[:available_to].include? availability_filter
    end.keys)
    super(user)
  end

  # Returns true if user has ALL of the passed permissions
  def has?(*required_permissions)
    if api_permissions.blank?
      return false
    else
      has_all = true
      
      required_permissions.each do |permission|
        has_all = has_all && api_permissions.include?(permission)
      end

      return has_all
    end
  end

  # Returns true if user is missing ANY of the passed permission sets
  def missing?(*required_permissions)
    if api_permissions.blank?
      return true
    else
      required_permissions.each do |permission|
        return true if !api_permissions.include?(permission)
      end

      return false
    end
  end

end