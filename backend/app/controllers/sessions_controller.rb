class SessionsController < Devise::SessionsController

  def new
    # First check if we need a special error message for oauth users that don't have passwords
    if params['user'] && !params['user']['email'].blank?
      @user = User.where(email: params['user']['email']).first
      if @user && !@user.user_defined_password
        flash['error'] = "Heads up! Your account doesn't have a password yet. So far you've only "\
          + "signed in with your Google account."
      end
    end

    super
  end

  def create
    super
  end

end