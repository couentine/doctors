#==========================================================================================================================================#
# 
# AUTHENTICATION TOKEN CREATION SERVICE
# 
# Use this to create all new authentication tokens. It verifies that the fields on the authentication token match all policies.
# 
#==========================================================================================================================================#

class AuthenticationTokenCreationService

  attr_reader :api_version
  attr_reader :params
  attr_reader :current_user
  attr_reader :authentication_token
  attr_reader :save_successful

  def initialize(api_version, current_user, params)
    raise ArgumentError.new('Unsupported api version') if api_version != 1

    @api_version = api_version
    @current_user = current_user
    @params = params
  end

  # Attempts to creates the new authentication token, stores it in @authentication_token and sets @save_successful
  def perform
    if @api_version == 1
      @authentication_token = Api::V1::DeserializableAuthenticationToken.new_from(@params)
    end

    @authentication_token.creator = @current_user
    policy = Pundit.policy(@current_user, @authentication_token)

    # Before saving, check that the current user is actually allowed
    if policy.user_can_manage_token?
      @save_successful = @authentication_token.save
    else
      @authentication_token.errors.add(:user_id, 'You do not have permission to create authentication tokens on behalf of this user')
      @save_successful = false
    end
  end

end