class UserPolicy < ApplicationPolicy
  attr_reader :current_user, :user, :users

  # NOTE: This policy uses different names than other policies because of a naming colision with the `user` variable.
  # In this policy, `current_user` refers to the authenticated user and `user` or `users` refer to the displayed records.
  def initialize(current_user, user_or_users)
    @current_user = current_user
    if (user_or_users.class == Mongoid::Criteria)
      @users = user_or_users
      @records = user_or_users
    else
      @user = user_or_users
      @record = user_or_users
    end
  end

  #=== ACTION POLICIES ===#

  def show?
    # All users and fields are shown, but relationships are conditionally displayed based on filters below
    return @current_user.has?('users:read')
  end
  
  def groups_index?
    return @current_user.has?('users:read') && @current_user.has?('groups:read') && show_all_fields?
  end

  #=== FILTER POLICIES ===#
  
  def show_all_fields?
    return true if !@user.has_private_domain
    return false if @current_user.blank?
    return @user.profile_visible_to(@current_user)
  end

  #=== USER-FACING METADATA ===#
  
  def meta
    return {
      current_user: {
        can_see_record: show_all_fields?
      }
    }
  end

  #=== SCOPES ===#

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end

end