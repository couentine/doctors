class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  
  def google_oauth2
    is_error = false
    
    begin
      @user = User.from_omniauth(request.env['omniauth.auth'])
      
      if @user.persisted?
        sign_in_and_redirect @user, :event => :authentication # throws if @user is not activated
        if is_navigational_format?
          set_flash_message(:notice, :success, :kind => "Google") 
        end
      else
        InfoItem.new(
          type: 'google-oauth2-error', 
          name: 'Google SSO Problem (User Not Persisted)',
          data: { user_record: @user.inspect, errors: @user.errors.to_h, request_details: request.env['omniauth.auth'] }
        ).save
        is_error = true
      end
    rescue => e
      InfoItem.new(
        type: 'google-oauth2-error', 
        name: 'Google SSO Problem (Error Thrown)',
        data: { error: e.to_s, request_details: request.env['omniauth.auth'] }
      ).save
      is_error = true
    end

    if is_error
      # There was some sort of problem saving (maybe a missing email) so redirect to signup instead
      flash[:error] = 'There was a problem creating an account for you using Google sign in. ' \
        + 'Please try creating an account and password manually.'
      redirect_to new_user_registration_url(sso_error: true)
    end
  end

  def failure
    flash[:error] = 'There was a problem using single-sign on. Please try signing in normally or creating an account and password manually.'
    redirect_to new_user_registration_url(sso_error: true)
  end

end