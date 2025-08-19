class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Skip CSRF verification for Devise Token Auth routes
  skip_before_action :verify_authenticity_token, if: :auth_request?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Root route method
  def index
    render json: { message: "Bullet Services API", status: "running" }
  end

  private

  def user_not_authorized(exception)
    render json: { error: exception.policy.class.to_s.underscore + "." + exception.query }, status: :forbidden
  end

  def auth_request?
    request.path.start_with?('/auth')
  end
end
