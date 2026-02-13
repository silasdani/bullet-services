# frozen_string_literal: true

module Api
  module V1
    class FreshbooksController < Api::V1::BaseController
      before_action :ensure_admin
      # Create FreshBooks invoice from local Invoice
      def create_invoice
        invoice = find_invoice
        client_id = determine_client_id(invoice)

        return render_client_id_error if client_id.blank?

        result = create_freshbooks_invoice(invoice, client_id)
        handle_invoice_creation_result(result)
      rescue ActiveRecord::RecordNotFound
        render_error(message: 'Invoice not found', status: :not_found)
      rescue FreshbooksError => e
        render_error(message: 'FreshBooks API error', details: e.message, status: :bad_gateway)
      end

      def find_invoice
        Invoice.find(params[:invoice_id])
      end

      def determine_client_id(invoice)
        params[:client_id] || invoice.freshbooks_client_id
      end

      def render_client_id_error
        render_error(
          message: 'Client ID is required',
          status: :unprocessable_entity
        )
      end

      def create_freshbooks_invoice(invoice, client_id)
        service = Freshbooks::InvoiceCreationService.new(
          invoice: invoice,
          client_id: client_id,
          lines: params[:lines] || []
        )
        service.call
        service
      end

      def handle_invoice_creation_result(service)
        if service.success?
          render_success(
            data: service.result,
            message: 'Invoice created in FreshBooks'
          )
        else
          render_error(
            message: 'Failed to create FreshBooks invoice',
            details: service.errors,
            status: :unprocessable_entity
          )
        end
      end

      private

      def ensure_admin
        return if current_user.admin?

        render_error(message: 'Unauthorized', status: :unauthorized)
      end
    end
  end
end
