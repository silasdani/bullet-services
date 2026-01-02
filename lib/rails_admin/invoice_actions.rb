# frozen_string_literal: true

module RailsAdmin
  # Helper methods for invoice actions
  module InvoiceActionHelpers
    def self.parse_freshbooks_error(error)
      error_msg = "Failed to void FreshBooks invoice: #{error.message}"
      return error_msg unless error.respond_to?(:response_body) && error.response_body.present?

      begin
        error_data = JSON.parse(error.response_body)
        if error_data.dig('response', 'errors')
          detailed_errors = error_data.dig('response', 'errors').map { |err| err['message'] }.join(', ')
          error_msg += " - #{detailed_errors}"
        end
      rescue JSON::ParserError
        # Ignore JSON parse errors
      end
      error_msg
    end
  end

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
              if invoice.freshbooks_client_id.present?
                client = FreshbooksClient.find_by(freshbooks_id: invoice.freshbooks_client_id)
                client_email = client&.email
                [client&.first_name, client&.last_name].compact.join(' ') if client
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
              invoices_client = Freshbooks::Invoices.new

              # Check invoice status in FreshBooks before voiding
              if freshbooks_invoice&.freshbooks_id.present?
                current_invoice = invoices_client.get(freshbooks_invoice.freshbooks_id)

                if current_invoice && current_invoice['status'] == 1 # draft status
                  flash[:error] = 'Cannot void a draft invoice. Please send the invoice first before voiding.'
                  redirect_back(fallback_location: fallback_path)
                  next
                end

                begin
                  invoices_client.void(freshbooks_invoice.freshbooks_id)

                  # Sync from FreshBooks to get the updated status (includes vis_state check)
                  sleep(0.5) # Brief delay to allow FreshBooks to process
                  freshbooks_invoice.sync_from_freshbooks
                  freshbooks_invoice.reload

                  # Status will be updated by sync based on vis_state
                  void_status_warning = "Invoice voided in FreshBooks but sync didn't update status. " \
                                        'Manual check may be needed.'
                  if freshbooks_invoice.status != 'voided' && freshbooks_invoice.status != 'void'
                    Rails.logger.warn(void_status_warning)
                  end
                rescue FreshbooksError => e
                  error_msg = InvoiceActionHelpers.parse_freshbooks_error(e)
                  raise StandardError, error_msg
                rescue StandardError => e
                  Rails.logger.error("Failed to void FreshBooks invoice: #{e.message}")
                  raise e
                end
              end

              # Sync already updated the status based on vis_state
              # Just ensure invoice is updated to match
              freshbooks_invoice.reload
              invoice.update!(status: 'voided', final_status: 'voided')
              flash[:success] = if %w[voided void].include?(freshbooks_invoice.status)
                                  'Invoice voided successfully'
                                else
                                  'Invoice voided successfully (status may update on next sync)'
                                end
            rescue StandardError => e
              Rails.logger.error("Failed to void invoice: #{e.message}")
              Rails.logger.error("Backtrace: #{e.backtrace.first(5).join('\n')}")
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

              # Void invoice in FreshBooks first
              if freshbooks_invoice&.freshbooks_id.present?
                begin
                  invoices_client.void(freshbooks_invoice.freshbooks_id)

                  # Sync from FreshBooks to get the updated status
                  sleep(0.5)
                  freshbooks_invoice.sync_from_freshbooks
                  freshbooks_invoice.reload

                  # Send voidance email to notify the client
                  invoices_client.send_by_email(
                    freshbooks_invoice.freshbooks_id,
                    email: client_email,
                    subject: "Invoice #{invoice.name || invoice.slug} - Voided",
                    message: 'This invoice has been voided. Please contact us if you have any questions.'
                  )
                rescue StandardError => e
                  Rails.logger.error("Failed to void FreshBooks invoice or send email: #{e.message}")
                  raise e
                end
              end

              # Update local records (sync should have already updated status)
              freshbooks_invoice.reload
              invoice.update!(status: 'voided', final_status: 'voided')

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
