# frozen_string_literal: true

# app/controllers/concerns/error_handling.rb
module ErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from ApplicationError, with: :handle_application_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from Pundit::NotAuthorizedError, with: :handle_unauthorized
  end

  private

  def handle_application_error(exception)
    render_error(
      message: exception.message,
      code: exception.code,
      details: exception.details,
      status: :unprocessable_entity
    )
  end

  def handle_not_found(_exception)
    render_error(
      message: 'Resource not found',
      code: 'NOT_FOUND',
      status: :not_found
    )
  end

  def handle_unauthorized(_exception)
    render_error(
      message: 'Access denied',
      code: 'UNAUTHORIZED',
      status: :forbidden
    )
  end
end
