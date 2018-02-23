class AuthenticationTokenPolicy < ApplicationPolicy
  attr_reader :user, :authentication_token, :authentication_tokens

  def initialize(user, token_or_tokens)
    @user = user
    if (token_or_tokens.class == Mongoid::Criteria)
      @authentication_tokens = token_or_tokens
      @records = token_or_tokens
    else
      @authentication_token = token_or_tokens
      @record = token_or_tokens
    end
  end

  #=== ACTION POLICIES ===#

  def index?
    return @user.present? && @user.has?('authentication_tokens:read')
  end

  def show?
    return @user.present? && @user.has?('authentication_tokens:read') && user_can_manage_token?
  end

  def create?
    return @user.present? && @user.has?('authentication_tokens:write')
  end

  def destroy?
    return @user.present? && @user.has?('authentication_tokens:write') && user_can_manage_token?
  end

  #=== USER-FACING METADATA ===#
  
  def meta
    return {
      current_user: {
        can_see_record: show?,
        can_delete_record: destroy?
      }
    }
  end

  #=== SCOPES ===#

  class Scope < ApplicationPolicy::Scope
    def resolve
      if @user.present?
        scope.where(user_id: @user.id)
      else
        nil
      end
    end
  end
  
  #=== UTILITY METHODS ===#

  # Returns true if the @user has permission to manage the @authentication_token
  def user_can_manage_token?
    raise ArgumentError.new('Record must be an instantiated AuthenticationToken') if !@authentication_token.is_a?(AuthenticationToken)

    @authentication_token_user = @authentication_token_user || User.find(@authentication_token.user_id) rescue nil

    if @authentication_token_user
      if @authentication_token_user.type == 'individual'
        # Tokens for individual users can only be created by the users themselves
        return true if @user.id == @authentication_token_user.id
      elsif (@authentication_token_user.type == 'group') && @authentication_token_user.proxy_group
        # Tokens for group users can only be created by group admins
        return true if @user.admin_of?(@authentication_token_user.proxy_group)
      end
    else
      return false
    end
  end

end