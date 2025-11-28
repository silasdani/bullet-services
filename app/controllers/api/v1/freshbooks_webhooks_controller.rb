# frozen_string_literal: true

module Api
  module V1
    class FreshbooksWebhooksController < ActionController::API
      skip_before_action :verify_authenticity_token, if: :verify_webhook_signature

      def create
        # Handle webhook verification (FreshBooks sends a verification request first)
        # According to: https://www.freshbooks.com/api/webhooks
        # FreshBooks sends verification with 'verifier' parameter in form-urlencoded data
        if params[:verifier].present? || params[:verification_code].present?
          handle_verification
          return
        end

        # For actual webhook events, verify signature
        unless verify_webhook_signature
          head :unauthorized
          return
        end

        # FreshBooks webhook payload structure
        # Events come as form-urlencoded: name=invoice.create&object_id=123&account_id=...
        event_type = params[:name] || params[:event] || request.headers['X-FreshBooks-Event']
        object_id = params[:object_id]

        Rails.logger.info "FreshBooks webhook received: #{event_type}"
        Rails.logger.info "  Object ID: #{object_id}"
        Rails.logger.info "  Account ID: #{params[:account_id]}"
        Rails.logger.info "  Business ID: #{params[:business_id]}"

        case event_type
        when 'payment.create', 'payment.updated'
          handle_payment_webhook_by_id(object_id)
        when 'invoice.create', 'invoice.updated'
          handle_invoice_webhook_by_id(object_id)
        else
          Rails.logger.info "Unhandled FreshBooks webhook event: #{event_type}"
        end

        head :ok
      rescue StandardError => e
        Rails.logger.error "FreshBooks webhook error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        head :internal_server_error
      end

      private

      def handle_payment_webhook_by_id(payment_id)
        return unless payment_id

        # Fetch payment details from FreshBooks API
        begin
          payments = Freshbooks::Payments.new
          payment_data = payments.get(payment_id)
          return unless payment_data

          invoice_id = payment_data['invoiceid'] || payment_data.dig('invoice', 'id')

          # Find local invoice by FreshBooks invoice ID
          freshbooks_invoice = FreshbooksInvoice.find_by(freshbooks_id: invoice_id)
          return unless freshbooks_invoice

          # Update invoice status
          freshbooks_invoice.update!(
            status: 'paid',
            amount_outstanding: 0
          )

          # Update local invoice if linked
          if freshbooks_invoice.invoice
            freshbooks_invoice.invoice.update!(
              final_status: 'paid',
              status: 'paid'
            )
          end

          # Create or update payment record
          FreshbooksPayment.find_or_create_by(freshbooks_id: payment_id) do |payment|
            payment.freshbooks_invoice_id = invoice_id
            payment.amount = extract_amount(payment_data['amount'])
            payment.date = parse_date(payment_data['date'])
            payment.payment_method = payment_data['type']
            payment.currency_code = payment_data.dig('amount', 'code')
            payment.raw_data = payment_data
          end

          Rails.logger.info "Payment processed for invoice #{invoice_id}"
        rescue FreshbooksError => e
          Rails.logger.error "Failed to fetch payment #{payment_id}: #{e.message}"
        end
      end

      def handle_invoice_webhook_by_id(invoice_id)
        return unless invoice_id

        # Fetch invoice details from FreshBooks API
        begin
          invoices = Freshbooks::Invoices.new
          invoice_data = invoices.get(invoice_id)
          return unless invoice_data

          # Update local invoice record if it exists
          freshbooks_invoice = FreshbooksInvoice.find_by(freshbooks_id: invoice_id)
          return unless freshbooks_invoice

          freshbooks_invoice.update!(
            status: invoice_data['status'] || invoice_data['v3_status'],
            amount_outstanding: extract_amount(invoice_data['outstanding'] || invoice_data['amount_outstanding']),
            raw_data: invoice_data
          )

          Rails.logger.info "Invoice updated: #{invoice_id}"
        rescue FreshbooksError => e
          Rails.logger.error "Failed to fetch invoice #{invoice_id}: #{e.message}"
        end
      end

      def extract_amount(amount_data)
        return nil unless amount_data

        amount_data.is_a?(Hash) ? amount_data['amount'].to_d : amount_data.to_d
      end

      def parse_date(date_string)
        return nil unless date_string

        Date.parse(date_string)
      rescue ArgumentError
        nil
      end

      private

      def handle_verification
        # FreshBooks sends a verification request with callback_id and verifier
        # According to: https://www.freshbooks.com/api/webhooks
        callback_id = params[:callback_id] || params[:id]
        verification_code = params[:verifier] || params[:verification_code]

        Rails.logger.info 'FreshBooks webhook verification request received'
        Rails.logger.info "  Callback ID: #{callback_id}"
        Rails.logger.info "  Verification code: #{verification_code.present? ? 'present' : 'missing'}"
        Rails.logger.info "  All params: #{params.inspect}"

        if verification_code.present? && callback_id.present?
          # Automatically verify the webhook via API
          begin
            webhooks = Freshbooks::Webhooks.new
            result = webhooks.verify(callback_id, verification_code)

            if result&.dig('verified')
              Rails.logger.info "✅ Webhook #{callback_id} verified successfully"
              render json: { status: 'verified', callback_id: callback_id }, status: :ok
            else
              Rails.logger.warn '⚠️  Webhook verification returned but status is unverified'
              render json: { status: 'pending', callback_id: callback_id }, status: :ok
            end
          rescue FreshbooksError => e
            Rails.logger.error "❌ Failed to verify webhook: #{e.message}"
            Rails.logger.error "Response: #{e.response_body}" if e.respond_to?(:response_body)
            # Still return 200 to acknowledge receipt
            render json: { status: 'verification_failed', error: e.message }, status: :ok
          end
        else
          # Just acknowledge the verification request (FreshBooks may send multiple requests)
          Rails.logger.info 'Verification request received (missing callback_id or verification_code)'
          render json: { status: 'received' }, status: :ok
        end
      end

      def verify_webhook_signature
        # Skip signature verification for verification requests
        return true if params[:verification_code].present? || params[:verifier].present?

        webhook_secret = Rails.application.config.freshbooks[:webhook_secret]
        return true if webhook_secret.blank? # Skip verification if not configured

        # FreshBooks uses X-FreshBooks-Hmac-SHA256 header for signature verification
        # Based on: https://www.freshbooks.com/api/webhooks
        signature = request.headers['X-FreshBooks-Hmac-SHA256']
        return false if signature.blank?

        # Compute expected signature
        # Note: FreshBooks sends form data, so we need to use request.form_data or request.raw_post
        data = request.form_data? ? request.form_data.to_json : request.raw_post
        expected_signature = Base64.strict_encode64(
          OpenSSL::HMAC.digest('sha256', webhook_secret, data)
        )

        ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
      end
    end
  end
end
