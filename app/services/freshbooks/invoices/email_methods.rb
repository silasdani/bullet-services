# frozen_string_literal: true

module Freshbooks
  module Invoices
    # Module containing email-related methods for the Invoices class
    module EmailMethods
      def send_by_email(invoice_id, email_params = {})
        endpoints = build_email_endpoints(invoice_id)
        payload = build_email_payload(email_params)

        result = try_email_endpoints(endpoints, payload)
        return result if result.present?

        return_manual_email_response
      end

      private

      def build_email_endpoints(invoice_id)
        [
          "invoices/invoices/#{invoice_id}/email",
          "invoices/invoices/#{invoice_id}/send",
          "invoices/invoices/#{invoice_id}/send_email"
        ]
      end

      def build_email_payload(email_params)
        {
          email: {
            email: email_params[:email],
            subject: email_params[:subject],
            message: email_params[:message]
          }.compact
        }
      end

      def try_email_endpoints(endpoints, payload)
        endpoints.each do |endpoint_path|
          result = try_single_email_endpoint(endpoint_path, payload)
          return result if result.present?
        end
        nil
      end

      def try_single_email_endpoint(endpoint_path, payload)
        path = build_path(endpoint_path)
        Rails.logger.info("Attempting to send invoice email via: #{path}")
        response = make_request(:post, path, body: payload.to_json)
        result = response.dig('response', 'result')
        Rails.logger.info("Invoice email sent successfully via #{endpoint_path}")
        result if result.present?
      rescue FreshbooksError => e
        Rails.logger.warn("Endpoint #{endpoint_path} failed: #{e.message}")
        nil
      rescue StandardError => e
        Rails.logger.warn("Endpoint #{endpoint_path} error: #{e.message}")
        nil
      end

      def return_manual_email_response
        Rails.logger.warn('FreshBooks API does not support direct email sending via API')
        Rails.logger.info('Invoice email must be sent manually from FreshBooks UI')

        {
          success: true,
          method: 'manual_required',
          message: 'Invoice email must be sent manually from FreshBooks. Use the invoice link to access it.'
        }
      end
    end
  end
end

