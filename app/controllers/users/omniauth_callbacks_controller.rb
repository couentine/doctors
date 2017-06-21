class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  
  def google_oauth2
    @user = User.from_omniauth(request.env["omniauth.auth"])
    
    if @user.persisted?
      sign_in_and_redirect @user, :event => :authentication # throws if @user is not activated
      if is_navigational_format?
        set_flash_message(:notice, :success, :kind => "Google") 
      end
    else 
      # There was some sort of problem saving (maybe a missing email) so redirect to signup instead
      session["devise.google_oauth2_data"] = request.env["omniauth.auth"]
      redirect_to new_user_registration_url
    end
  end

  def canvas
    @user = User.from_omniauth(request.env["omniauth.auth"])
    
    if @user.persisted?
      sign_in_and_redirect @user, :event => :authentication # throws if @user is not activated
      if is_navigational_format?
        set_flash_message(:notice, :success, :kind => "Canvas") 
      end
    else 
      # There was some sort of problem saving (maybe a missing email) so redirect to signup instead
      session["devise.canvas_data"] = request.env["omniauth.auth"]
      redirect_to new_user_registration_url
    end
  end

  def failure
    redirect_to root_path
  end

end