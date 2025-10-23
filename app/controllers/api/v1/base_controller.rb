# frozen_string_literal: true

module Api
  module V1
    class BaseController < ActionController::API
      include Pundit::Authorization
      include ErrorHandling
      include InputValidation
      include DeviseTokenAuth::Concerns::SetUserByToken

      before_action :authenticate_user!
      before_action :set_pagination_params
      before_action :sanitize_params

      rescue_from Pundit::NotAuthorizedError, with: :handle_authorization_error
      rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
      rescue_from StandardError, with: :handle_internal_error

      private

      def set_pagination_params
        @page = params[:page]&.to_i || 1
        @per_page = [params[:per_page]&.to_i || 20, 100].min
      end

      def handle_authorization_error(exception)
        render_error(
          message: 'Access denied',
          details: exception.message,
          status: :forbidden
        )
      end

      def handle_not_found(_exception)
        render_error(
          message: 'Resource not found',
          status: :not_found
        )
      end

      def handle_internal_error(exception)
        Rails.logger.error "Internal error: #{exception.message}"
        Rails.logger.error exception.backtrace.join("\n")

        render_error(
          message: 'Internal server error',
          status: :internal_server_error
        )
      end

      def render_error(message:, details: nil, status: :unprocessable_entity, code: nil)
        error_response = { error: message }
        error_response[:details] = details if details.present?
        error_response[:code] = code if code.present?

        render json: error_response, status: status
      end

      def render_success(data:, message: nil, meta: nil, status: :ok)
        response = { data: data }
        response[:message] = message if message.present?
        response[:meta] = meta if meta.present?

        render json: response, status: status
      end

      def pagination_meta(collection)
        {
          current_page: collection.current_page,
          total_pages: collection.total_pages,
          total_count: collection.total_count,
          per_page: collection.limit_value,
          has_next_page: collection.next_page.present?,
          has_prev_page: collection.prev_page.present?
        }
      end
    end
  end
end
