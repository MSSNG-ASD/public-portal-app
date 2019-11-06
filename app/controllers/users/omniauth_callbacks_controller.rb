class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController

  def google_oauth2
    @user = User.from_omniauth(request.env["omniauth.auth"])
    # puts request.env["omniauth.auth"]
    # byebug
		if @user.persisted?
      # set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
      sign_in_and_redirect @user, event: :authentication #this will throw if @user is not activated
    else
      session["devise.google_data"] = request.env["omniauth.auth"].except(:extra) # Removing extra as it can overflow some session stores
      redirect_to root_url
    end
  end

  def failure
    redirect_to root_url
  end

end