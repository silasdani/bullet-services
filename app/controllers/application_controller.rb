class ApplicationController < ActionController::API
  include Pundit::Authorization
  include DeviseTokenAuth::Concerns::SetUserByToken

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized(exception)
    render json: { error: exception.policy.class.to_s.underscore + "." + exception.query }, status: :forbidden
  end
end

