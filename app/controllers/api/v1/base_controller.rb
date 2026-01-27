# frozen_string_literal: true

module Api
  module V1
    class BaseController < ActionController::API
      include Pundit::Authorization
      include ErrorHandling
      include InputValidation
      include DeviseTokenAuth::Concerns::SetUserByToken

      before_action :set_request_format
      before_action :authenticate_user!
      before_action :check_user_blocked
      before_action :set_pagination_params

      rescue_from StandardError, with: :handle_internal_error

      private

      def set_request_format
        request.format = :json if request.format.html?
      end

      def set_pagination_params
        @page = params[:page]&.to_i || 1
        @per_page = [params[:per_page]&.to_i || 20, 100].min
      end

      # Authorization and not found errors are handled by ErrorHandling concern
      # These methods are kept for backward compatibility but delegate to concern

      def handle_internal_error(exception)
        log_internal_error(exception)
        render_error(
          message: error_message_for(exception),
          details: error_details_for(exception),
          status: :internal_server_error
        )
      end

      def log_internal_error(exception)
        Rails.logger.error "Internal error: #{exception.class.name}: #{exception.message}"
        return unless Rails.env.development? || Rails.env.test?

        Rails.logger.error exception.backtrace.join("\n")
      end

      def error_message_for(exception)
        Rails.env.production? ? 'Internal server error' : exception.message
      end

      def error_details_for(exception)
        return nil if Rails.env.production?

        exception.backtrace.first(5)
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

      def check_user_blocked
        return unless current_user&.blocked?

        render_error(
          message: 'Your account has been blocked. Please contact an administrator.',
          status: :forbidden
        )
      end
    end
  end
end
