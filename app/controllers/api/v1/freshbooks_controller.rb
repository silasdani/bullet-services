# frozen_string_literal: true

module Api
  module V1
    class FreshbooksController < Api::V1::BaseController
      before_action :ensure_admin

      # Manual sync endpoints
      def sync_clients
        Freshbooks::SyncClientsJob.perform_later
        render_success(
          data: { message: 'Client sync job queued' },
          status: :accepted
        )
      end

      def sync_invoices
        Freshbooks::SyncInvoicesJob.perform_later
        render_success(
          data: { message: 'Invoice sync job queued' },
          status: :accepted
        )
      end

      def sync_payments
        Freshbooks::SyncPaymentsJob.perform_later
        render_success(
          data: { message: 'Payment sync job queued' },
          status: :accepted
        )
      end

      # Create FreshBooks invoice from local Invoice
      def create_invoice
        invoice = Invoice.find(params[:invoice_id])
        client_id = params[:client_id] || invoice.freshbooks_client_id

        if client_id.blank?
          render_error(
            message: 'Client ID is required',
            status: :unprocessable_entity
          )
          return
        end

        service = Freshbooks::InvoiceCreationService.new(
          invoice: invoice,
          client_id: client_id,
          lines: params[:lines] || []
        )

        result = service.call

        if service.success?
          render_success(
            data: result,
            message: 'Invoice created in FreshBooks'
          )
        else
          render_error(
            message: 'Failed to create FreshBooks invoice',
            details: service.errors,
            status: :unprocessable_entity
          )
        end
      rescue ActiveRecord::RecordNotFound
        render_error(
          message: 'Invoice not found',
          status: :not_found
        )
      rescue FreshbooksError => e
        render_error(
          message: 'FreshBooks API error',
          details: e.message,
          status: :bad_gateway
        )
      end

      # Get connection status
      def status
        token = FreshbooksToken.current

        if token.nil?
          render_success(
            data: {
              connected: false,
              message: 'FreshBooks not connected'
            }
          )
        elsif token.expired?
          render_success(
            data: {
              connected: true,
              expired: true,
              message: 'Token expired, refresh needed'
            }
          )
        else
          render_success(
            data: {
              connected: true,
              expired: false,
              business_id: token.business_id,
              expires_at: token.token_expires_at
            }
          )
        end
      end

      private

      def ensure_admin
        authorize :freshbooks, :manage?
      end
    end
  end
end
