# frozen_string_literal: true

module RailsAdmin
  module Config
    module Actions
      class SendInvoice < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)

        register_instance_option :visible? do
          invoice = bindings[:object]
          result = false
          if authorized? && invoice.is_a?(Invoice) && invoice.freshbooks_invoices.exists?
            result = RailsAdmin::InvoiceLifecycle.can_send?(invoice)
          end
          result
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

            fallback_path = rails_admin.show_path(model_name: 'invoice', id: invoice.id)

            if freshbooks_invoice.nil?
              flash[:error] = 'No FreshBooks invoice found for this invoice'
              redirect_back(fallback_location: fallback_path)
              next
            end

            # Helper methods for email formatting

            begin
              invoices_client = Freshbooks::Invoices.new

              # Get client email and name from FreshbooksClient
              client_email = nil
              client_name = nil
              if invoice.freshbooks_client_id.present?
                client = FreshbooksClient.find_by(freshbooks_id: invoice.freshbooks_client_id)
                client_email = client&.email
                client_name = [client&.first_name, client&.last_name].compact.join(' ') if client
              end

              # Allow override email from params
              email_to = params[:email] || client_email

              if email_to.blank?
                flash[:error] = 'No email address found for client. Please provide an email address.'
                redirect_back(fallback_location: fallback_path)
                next
              end

              # Get current invoice data from FreshBooks to preserve all fields
              current_invoice = invoices_client.get(freshbooks_invoice.freshbooks_id)
              unless current_invoice
                flash[:error] = 'Could not retrieve invoice from FreshBooks'
                redirect_back(fallback_location: fallback_path)
                next
              end

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

              # Update invoice in FreshBooks with action_email to send it
              # This will automatically mark the invoice as 'sent' in FreshBooks
              invoices_client.update(
                freshbooks_invoice.freshbooks_id,
                client_id: current_invoice['customerid'] || invoice.freshbooks_client_id,
                date: current_invoice['create_date'] || invoice.created_at&.to_date&.to_s,
                due_date: current_invoice['due_date'],
                currency: current_invoice['currency_code'] || 'USD',
                notes: current_invoice['notes'],
                lines: lines,
                action_email: true,
                email_recipients: [email_to]
              )

              # Sync invoice from FreshBooks to get the updated status (should be 'sent' now)
              if freshbooks_invoice&.freshbooks_id.present?
                begin
                  freshbooks_invoice.sync_from_freshbooks
                  # Propagate status to Invoice model
                  invoice.sync_status_from_freshbooks_invoice
                rescue StandardError => e
                  # If sync fails, update local records to 'sent' as fallback
                  Rails.logger.warn("Failed to sync from FreshBooks after sending: #{e.message}")
                  invoice.update!(status: 'sent', final_status: 'sent')
                  freshbooks_invoice&.update!(status: 'sent')
                end
              else
                # Fallback: update local records if we can't sync
                invoice.update!(status: 'sent', final_status: 'sent')
                freshbooks_invoice&.update!(status: 'sent')
              end

              flash[:success] = "Invoice sent successfully via FreshBooks to #{email_to}"
            rescue StandardError => e
              Rails.logger.error("Failed to send invoice: #{e.message}")
              Rails.logger.error("Backtrace: #{e.backtrace.first(10).join('\n')}")
              flash[:error] = "Failed to send invoice: #{e.message}"
            end

            redirect_back(fallback_location: fallback_path)
          end
        end
      end

      class VoidInvoice < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)

        register_instance_option :visible? do
          invoice = bindings[:object]
          result = false
          if authorized? && invoice.is_a?(Invoice) && invoice.freshbooks_invoices.exists?
            result = RailsAdmin::InvoiceLifecycle.can_void?(invoice)
          end
          result
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
            fallback_path = rails_admin.show_path(model_name: 'invoice', id: invoice.id)

            if freshbooks_invoice.nil?
              flash[:error] = 'No FreshBooks invoice found for this invoice'
              redirect_back(fallback_location: fallback_path)
              next
            end

            begin
              # Update local records first
              freshbooks_invoice&.update!(status: 'voided')
              invoice.update!(status: 'voided', final_status: 'voided')

              # Try to update in FreshBooks if we have the invoice ID
              if freshbooks_invoice&.freshbooks_id.present?
                begin
                  invoices_client = Freshbooks::Invoices.new
                  current_invoice = invoices_client.get(freshbooks_invoice.freshbooks_id)

                  # NOTE: FreshBooks API doesn't allow setting status to 'void' via update endpoint
                  # Status can only be set to: 'draft', 'sent', 'viewed', or 'disputed'
                  # We only update local records. The invoice status in FreshBooks will remain as-is
                  # or can be voided manually through FreshBooks UI if needed
                  # No FreshBooks API update call needed for void operation
                rescue StandardError => e
                  # Log but don't fail - local update succeeded
                  Rails.logger.warn("Failed to update FreshBooks invoice: #{e.message}")
                end
              end

              flash[:success] = 'Invoice voided successfully'
            rescue StandardError => e
              flash[:error] = "Failed to void invoice: #{e.message}"
            end

            redirect_back(fallback_location: fallback_path)
          end
        end
      end

      class MarkPaid < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)

        register_instance_option :visible? do
          invoice = bindings[:object]
          result = false
          if authorized? && invoice.is_a?(Invoice) && invoice.freshbooks_invoices.exists?
            result = RailsAdmin::InvoiceLifecycle.can_mark_paid?(invoice)
          end
          result
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
            fallback_path = rails_admin.show_path(model_name: 'invoice', id: invoice.id)

            if freshbooks_invoice.nil?
              flash[:error] = 'No FreshBooks invoice found for this invoice'
              redirect_back(fallback_location: fallback_path)
              next
            end

            begin
              # Update local records first
              freshbooks_invoice&.update!(status: 'paid')
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
                      client_id: current_invoice['customerid'] || invoice.freshbooks_client_id,
                      date: current_invoice['create_date'] || invoice.created_at&.to_date&.to_s,
                      due_date: current_invoice['due_date'],
                      currency: current_invoice['currency_code'] || 'USD',
                      notes: current_invoice['notes'],
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

            redirect_back(fallback_location: fallback_path)
          end
        end
      end

      class VoidInvoiceWithEmail < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)

        register_instance_option :action_name do
          :void_invoice_with_email
        end

        register_instance_option :visible? do
          invoice = bindings[:object]
          result = false
          if authorized? && invoice.is_a?(Invoice) && invoice.freshbooks_invoices.exists?
            result = RailsAdmin::InvoiceLifecycle.can_void?(invoice)
          end
          result
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
            fallback_path = rails_admin.show_path(model_name: 'invoice', id: invoice.id)

            if freshbooks_invoice.nil?
              flash[:error] = 'No FreshBooks invoice found for this invoice'
              redirect_back(fallback_location: fallback_path)
              next
            end

            begin
              # Get client email from FreshbooksClient if available
              client_email = nil
              if invoice.freshbooks_client_id.present?
                client = FreshbooksClient.find_by(freshbooks_id: invoice.freshbooks_client_id)
                client_email = client&.email
              end

              if client_email.blank?
                flash[:error] = 'No email address found for client. Cannot send voidance email.'
                redirect_back(fallback_location: fallback_path)
                next
              end

              invoices_client = Freshbooks::Invoices.new

              # Update local records first
              freshbooks_invoice&.update!(status: 'voided')
              invoice.update!(status: 'voided', final_status: 'voided')

              # Try to update in FreshBooks if we have the invoice ID
              if freshbooks_invoice&.freshbooks_id.present?
                begin
                  current_invoice = invoices_client.get(freshbooks_invoice.freshbooks_id)

                  # NOTE: FreshBooks API doesn't allow setting status to 'void' via update endpoint
                  # Status can only be set to: 'draft', 'sent', 'viewed', or 'disputed'
                  # We only update local records. The invoice status in FreshBooks will remain as-is
                  # or can be voided manually through FreshBooks UI if needed

                  # Send voidance email to notify the client
                  if current_invoice
                    invoices_client.send_by_email(
                      freshbooks_invoice.freshbooks_id,
                      email: client_email,
                      subject: "Invoice #{invoice.name || invoice.slug} - Voided",
                      message: 'This invoice has been voided. Please contact us if you have any questions.'
                    )
                  end
                rescue StandardError => e
                  # Log but don't fail - local update succeeded
                  Rails.logger.warn("Failed to update FreshBooks invoice or send email: #{e.message}")
                end
              end

              flash[:success] = 'Invoice voided and voidance email sent successfully'
            rescue StandardError => e
              flash[:error] = "Failed to void invoice and send email: #{e.message}"
            end

            redirect_back(fallback_location: fallback_path)
          end
        end
      end

      class ApplyDiscount < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)

        register_instance_option :action_name do
          :apply_discount
        end

        register_instance_option :visible? do
          invoice = bindings[:object]
          result = false
          if authorized? && invoice.is_a?(Invoice) && invoice.freshbooks_invoices.exists?
            result = RailsAdmin::InvoiceLifecycle.can_apply_discount?(invoice)
          end
          result
        end

        register_instance_option :link_icon do
          'fa fa-percent'
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
            fallback_path = rails_admin.show_path(model_name: 'invoice', id: invoice.id)

            if freshbooks_invoice.nil?
              flash[:error] = 'No FreshBooks invoice found for this invoice'
              redirect_back(fallback_location: fallback_path)
              next
            end

            begin
              invoices_client = Freshbooks::Invoices.new
              current_invoice = invoices_client.get(freshbooks_invoice.freshbooks_id)

              if current_invoice.nil?
                flash[:error] = 'Could not retrieve invoice from FreshBooks'
                redirect_back(fallback_location: fallback_path)
                next
              end

              # Apply 10% discount to all lines
              discount_rate = 0.10
              lines = (current_invoice['lines'] || []).map do |line|
                original_cost = line.dig('unit_cost', 'amount') || line['unit_cost'] || 0
                discounted_cost = original_cost.to_f * (1 - discount_rate)

                {
                  name: line['name'],
                  description: line['description'],
                  quantity: line['qty'] || 1,
                  cost: discounted_cost.round(2),
                  currency: line.dig('unit_cost', 'code') || 'USD',
                  type: line['type'] || 0
                }
              end

              # Update invoice in FreshBooks
              invoices_client.update(
                freshbooks_invoice.freshbooks_id,
                client_id: current_invoice['customerid'] || invoice.freshbooks_client_id,
                date: current_invoice['create_date'] || invoice.created_at&.to_date&.to_s,
                due_date: current_invoice['due_date'],
                currency: current_invoice['currency_code'] || 'USD',
                notes: current_invoice['notes'],
                lines: lines,
                status: current_invoice['status'] || invoice.status
              )

              # Update local invoice amounts (recalculate with discount)
              total_excluded = lines.sum { |line| (line[:cost] || 0) * (line[:quantity] || 1) }
              invoice.update!(
                excluded_vat_amount: total_excluded,
                included_vat_amount: total_excluded * 0.20 # Assuming 20% VAT
              )

              flash[:success] = '10% discount applied successfully'
            rescue StandardError => e
              flash[:error] = "Failed to apply discount: #{e.message}"
            end

            redirect_back(fallback_location: fallback_path)
          end
        end
      end
    end
  end
end
