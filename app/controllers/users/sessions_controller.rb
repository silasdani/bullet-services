# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    before_action :check_admin_access, only: [:create]

    private

    def check_admin_access
      email = params.dig(:user, :email) || params[:email]
      return if email.blank?

      user = User.find_by(email: email)

      if user.nil?
        # Don't set flash message here - let Devise handle authentication errors
        redirect_to new_user_session_path and return
      end

      return if user.is_admin?

      flash[:alert] = 'Access denied. This portal is restricted to administrators only.'
      redirect_to new_user_session_path and return
    end

    def after_sign_in_path_for(resource)
      if resource.is_admin?
        rails_admin_path
      else
        root_path
      end
    end
  end
end
