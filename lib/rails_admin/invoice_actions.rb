# frozen_string_literal: true

module RailsAdmin
  module Config
    module Actions
      class SendInvoice < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)

        register_instance_option :visible? do
          authorized? && bindings[:object].is_a?(Invoice)
        end

        register_instance_option :link_icon do
          'fa fa-paper-plane'
        end

        register_instance_option :member do
          true
        end

        register_instance_option :collection do
          false
        end

        register_instance_option :http_methods do
          [:post]
        end

        register_instance_option :show_in_navigation do
          false
        end

        register_instance_option :controller do
          proc do
            invoice = @object
            freshbooks_invoice = invoice.freshbooks_invoices.first

            if freshbooks_invoice.nil?
              flash[:error] = 'No FreshBooks invoice found for this invoice'
              redirect_to back
              next
            end

            begin
              invoices_client = Freshbooks::Invoices.new

              # Get client email from FreshbooksClient if available
              client_email = nil
              if invoice.freshbooks_client_id.present?
                client = FreshbooksClient.find_by(freshbooks_id: invoice.freshbooks_client_id)
                client_email = client&.email
              end

              if client_email.blank?
                flash[:error] = 'No email address found for client. Please provide an email address.'
                redirect_to back
                next
              end

              result = invoices_client.send_by_email(
                freshbooks_invoice.freshbooks_id,
                email: params[:email] || client_email,
                subject: params[:subject] || "Invoice #{invoice.name || invoice.slug}",
                message: params[:message] || 'Please find your invoice attached.'
              )

              flash[:success] = 'Invoice sent successfully'
            rescue StandardError => e
              flash[:error] = "Failed to send invoice: #{e.message}"
            end

            redirect_to back
          end
        end
      end

      class VoidInvoice < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)

        register_instance_option :visible? do
          authorized? && bindings[:object].is_a?(Invoice)
        end

        register_instance_option :link_icon do
          'fa fa-ban'
        end

        register_instance_option :member do
          true
        end

        register_instance_option :collection do
          false
        end

        register_instance_option :http_methods do
          [:post]
        end

        register_instance_option :show_in_navigation do
          false
        end

        register_instance_option :controller do
          proc do
            invoice = @object
            freshbooks_invoice = invoice.freshbooks_invoices.first

            if freshbooks_invoice.nil?
              flash[:error] = 'No FreshBooks invoice found for this invoice'
              redirect_to back
              next
            end

            begin
              # Update local records first
              freshbooks_invoice.update!(status: 'voided') if freshbooks_invoice
              invoice.update!(status: 'voided', final_status: 'voided')

              # Try to update in FreshBooks if we have the invoice ID
              if freshbooks_invoice&.freshbooks_id.present?
                begin
                  invoices_client = Freshbooks::Invoices.new
                  current_invoice = invoices_client.get(freshbooks_invoice.freshbooks_id)

                  if current_invoice
                    # Build lines array from current invoice
                    lines = (current_invoice['lines'] || []).map do |line|
                      {
                        name: line['name'],
                        description: line['description'],
                        quantity: line['qty'] || 1,
                        cost: line.dig('unit_cost', 'amount') || line['unit_cost'],
                        currency: line.dig('unit_cost', 'code') || 'USD',
                        type: line['type'] || 0
                      }
                    end

                    invoices_client.update(
                      freshbooks_invoice.freshbooks_id,
                      client_id: current_invoice.dig('customerid') || invoice.freshbooks_client_id,
                      date: current_invoice.dig('create_date') || invoice.created_at&.to_date&.to_s,
                      due_date: current_invoice.dig('due_date'),
                      currency: current_invoice.dig('currency_code') || 'USD',
                      notes: current_invoice.dig('notes'),
                      lines: lines,
                      status: 'voided'
                    )
                  end
                rescue StandardError => e
                  # Log but don't fail - local update succeeded
                  Rails.logger.warn("Failed to update FreshBooks invoice: #{e.message}")
                end
              end

              flash[:success] = 'Invoice voided successfully'
            rescue StandardError => e
              flash[:error] = "Failed to void invoice: #{e.message}"
            end

            redirect_to back
          end
        end
      end

      class MarkPaid < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)

        register_instance_option :visible? do
          authorized? && bindings[:object].is_a?(Invoice)
        end

        register_instance_option :link_icon do
          'fa fa-check'
        end

        register_instance_option :member do
          true
        end

        register_instance_option :collection do
          false
        end

        register_instance_option :http_methods do
          [:post]
        end

        register_instance_option :show_in_navigation do
          false
        end

        register_instance_option :controller do
          proc do
            invoice = @object
            freshbooks_invoice = invoice.freshbooks_invoices.first

            if freshbooks_invoice.nil?
              flash[:error] = 'No FreshBooks invoice found for this invoice'
              redirect_to back
              next
            end

            begin
              # Update local records first
              freshbooks_invoice.update!(status: 'paid') if freshbooks_invoice
              invoice.update!(status: 'paid', final_status: 'paid')

              # Try to update in FreshBooks if we have the invoice ID
              if freshbooks_invoice&.freshbooks_id.present?
                begin
                  invoices_client = Freshbooks::Invoices.new
                  current_invoice = invoices_client.get(freshbooks_invoice.freshbooks_id)

                  if current_invoice
                    # Build lines array from current invoice
                    lines = (current_invoice['lines'] || []).map do |line|
                      {
                        name: line['name'],
                        description: line['description'],
                        quantity: line['qty'] || 1,
                        cost: line.dig('unit_cost', 'amount') || line['unit_cost'],
                        currency: line.dig('unit_cost', 'code') || 'USD',
                        type: line['type'] || 0
                      }
                    end

                    invoices_client.update(
                      freshbooks_invoice.freshbooks_id,
                      client_id: current_invoice.dig('customerid') || invoice.freshbooks_client_id,
                      date: current_invoice.dig('create_date') || invoice.created_at&.to_date&.to_s,
                      due_date: current_invoice.dig('due_date'),
                      currency: current_invoice.dig('currency_code') || 'USD',
                      notes: current_invoice.dig('notes'),
                      lines: lines,
                      status: 'paid'
                    )
                  end
                rescue StandardError => e
                  # Log but don't fail - local update succeeded
                  Rails.logger.warn("Failed to update FreshBooks invoice: #{e.message}")
                end
              end

              flash[:success] = 'Invoice marked as paid'
            rescue StandardError => e
              flash[:error] = "Failed to mark invoice as paid: #{e.message}"
            end

            redirect_to back
          end
        end
      end
    end
  end
end
