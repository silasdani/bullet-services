# frozen_string_literal: true

module Api
  module V1
    class FreshbooksWebhooksController < ActionController::API
      include FreshbooksWebhookHandling
      include FreshbooksWebhookVerification

      # ActionController::API doesn't include CSRF protection by default,
      # so verify_authenticity_token callback doesn't exist

      def create
        return handle_verification if verification_request?

        return head(:unauthorized) unless verify_webhook_signature

        process_webhook_event
        head :ok
      rescue StandardError => e
        handle_webhook_error(e)
        head :internal_server_error
      end

      def verification_request?
        params[:verifier].present? || params[:verification_code].present?
      end

      def process_webhook_event
        event_type = extract_event_type
        object_id = params[:object_id]

        log_webhook_received(event_type, object_id)

        case event_type
        when 'payment.create', 'payment.updated'
          handle_payment_webhook_by_id(object_id)
        when 'invoice.create', 'invoice.updated'
          handle_invoice_webhook_by_id(object_id)
        else
          Rails.logger.info "Unhandled FreshBooks webhook event: #{event_type}"
        end
      end

      def extract_event_type
        params[:name] || params[:event] || request.headers['X-FreshBooks-Event']
      end

      def log_webhook_received(event_type, object_id)
        Rails.logger.info "FreshBooks webhook received: #{event_type}"
        Rails.logger.info "  Object ID: #{object_id}"
        Rails.logger.info "  Account ID: #{params[:account_id]}"
        Rails.logger.info "  Business ID: #{params[:business_id]}"
      end

      def handle_webhook_error(error)
        Rails.logger.error "FreshBooks webhook error: #{error.message}"
        Rails.logger.error error.backtrace.join("\n")
      end
    end
  end
end
