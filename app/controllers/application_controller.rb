class ApplicationController < ActionController::API
  include Pundit::Authorization
  include DeviseTokenAuth::Concerns::SetUserByToken
  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :nickname, :role, :image])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :nickname, :role, :image])
  end

  private

  def user_not_authorized(exception)
    render json: { error: exception.policy.class.to_s.underscore + "." + exception.query }, status: :forbidden
  end
end

