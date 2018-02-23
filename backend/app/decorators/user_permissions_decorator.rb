class UserPermissionsDecorator < SimpleDelegator

  attr_accessor :available_permission_sets

  def initialize(user, authentication_token = nil)
    @authentication_token = authentication_token
    
    if @authentication_token.blank?
      # The user is logged into the web UI, grant all internal permission sets
      self.available_permission_sets = ApplicationPolicy::PERMISSION_SETS.select do |key, permission_set| 
        permission_set[:api_access].include?(:internal)
      end.keys
    else
      # The user is using the API, grant only permission sets from their token and filter out any which shouldn't be available externally
      externally_allowed_permission_sets = ApplicationPolicy::PERMISSION_SETS.select do |key, permission_set| 
        permission_set[:api_access].include?(:external)
      end.keys
      self.available_permission_sets = @authentication_token.permission_sets.select do |permission_set|
        externally_allowed_permission_sets.include?(permission_set)
      end
    end

    super(user)
  end

  # Returns true if user has ALL of the passed permission sets
  def has?(*required_permission_sets)
    if available_permission_sets.blank?
      return false
    else
      has_all = true
      
      required_permission_sets.each do |permission_set|
        has_all = has_all && available_permission_sets.include?(permission_set)
      end

      return has_all
    end
  end

  # Returns true if user is missing ANY of the passed permission sets
  def missing?(*required_permission_sets)
    if available_permission_sets.blank?
      return true
    else
      required_permission_sets.each do |permission_set|
        return true if !available_permission_sets.include?(permission_set)
      end

      return false
    end
  end

end