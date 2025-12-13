# frozen_string_literal: true

class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  include Pundit::Authorization

  # Skip CSRF verification for Devise Token Auth routes
  skip_before_action :verify_authenticity_token, if: :auth_request?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Root route method (redirected to website#home in routes)
  def index
    redirect_to root_path
  end

  private

  def user_not_authorized(exception)
    render json: { error: "#{exception.policy.class.to_s.underscore}.#{exception.query}" }, status: :forbidden
  end

  def auth_request?
    request.path.start_with?('/auth')
  end
end
