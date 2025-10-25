# frozen_string_literal: true

class Api::V1::BaseController < ActionController::API
  include Pundit::Authorization
  include DeviseTokenAuth::Concerns::SetUserByToken
  before_action :authenticate_user!

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized(exception)
    policy_name = exception.policy.class.to_s.underscore
    query = exception.query.to_s

    # Try to get a custom message from I18n, fall back to default if not found
    message = I18n.t(
      query,
      scope: [ :pundit, policy_name ],
      default: I18n.t("pundit.default")
    )

    render json: { error: message }, status: :forbidden
  end
end
