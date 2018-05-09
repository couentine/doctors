class UserPermissionsDecorator < SimpleDelegator

  attr_accessor :available_permission_sets, :access_method

  def initialize(user, authentication_token = nil, access_method = nil)
    self.access_method = access_method
    unfiltered_permission_sets = ApplicationPolicy::PERMISSION_SETS.keys
    availability_filter = nil
    
    if authentication_token.present?
      # This request comes from an api user so start with the permission sets from their token.
      unfiltered_permission_sets = authentication_token.permission_sets
      availability_filter = :api_user
    elsif user.present?
      availability_filter = :web_user
    elsif access_method == :web
      availability_filter = :web_visitor
    else
      availability_filter = :api_visitor
    end

    # Now filter the permission sets by only those which are available based on the current authentication type / access method combo
    self.available_permission_sets = unfiltered_permission_sets & (ApplicationPolicy::PERMISSION_SETS.select do |permission_set, settings|
      settings[:available_to].include? availability_filter
    end.keys)
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