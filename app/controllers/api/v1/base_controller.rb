# frozen_string_literal: true

class Api::V1::BaseController < ActionController::API
  include Pundit::Authorization
  include DeviseTokenAuth::Concerns::SetUserByToken
  before_action :authenticate_user!

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized(exception)
    render json: { error: exception.policy.class.to_s.underscore + "." + exception.query }, status: :forbidden
  end
end
