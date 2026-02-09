# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    layout 'admin'
    before_action :check_admin_access, only: [:create]

    private

    def check_admin_access
      email = params.dig(:user, :email) || params[:email]
      return if email.blank?

      user = User.find_by(email: email)

      # Let Devise handle authentication errors for non-existent users
      return if user.nil?

      return if user.is_admin?

      flash[:alert] = 'Access denied. This portal is restricted to administrators only.'
      redirect_to new_user_session_path and return
    end

    def after_sign_in_path_for(resource)
      if resource.is_admin?
        '/admin'
      else
        root_path
      end
    end

    def after_sign_out_path_for(_resource_or_scope)
      '/admin'
    end
  end
end
