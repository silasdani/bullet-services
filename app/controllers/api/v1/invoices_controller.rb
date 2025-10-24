# frozen_string_literal: true

module Api
  module V1
    class InvoicesController < Api::V1::BaseController
      before_action :set_invoice, only: %i[show update destroy]

      def index
        authorize Invoice
        @invoices = Invoice.order(created_at: :desc)
        render json: @invoices
      end

      def show
        authorize @invoice
        render json: @invoice
      end

      def create
        @invoice = Invoice.new(invoice_params)
        authorize @invoice

        if @invoice.save
          render json: @invoice, status: :created
        else
          render json: { errors: @invoice.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        authorize @invoice

        if @invoice.update(invoice_params)
          render json: @invoice
        else
          render json: { errors: @invoice.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        authorize @invoice
        @invoice.destroy
        head :no_content
      end

      def csv_import
        authorize Invoice, :create?

        if params[:csv_file].blank?
          render json: { error: 'CSV file is required' }, status: :unprocessable_entity
          return
        end

        import_service = InvoiceCsvImportService.new(
          csv_file: params[:csv_file],
          user: current_user
        )

        result = import_service.call

        if result.success?
          render json: {
            success: true,
            message: 'CSV import completed',
            results: result.import_results
          }
        else
          render json: {
            success: false,
            error: 'CSV import failed',
            message: result.errors.join(', '),
            results: result.import_results
          }, status: :unprocessable_entity
        end
      end

      private

      def set_invoice
        @invoice = Invoice.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Invoice not found' }, status: :not_found
      end

      def invoice_params
        params.require(:invoice).permit(
          :name, :slug, :webflow_item_id, :is_archived, :is_draft,
          :webflow_created_on, :webflow_published_on, :freshbooks_client_id,
          :job, :wrs_link, :included_vat_amount, :excluded_vat_amount,
          :status_color, :status, :final_status, :invoice_pdf_link
        )
      end
    end
  end
end
