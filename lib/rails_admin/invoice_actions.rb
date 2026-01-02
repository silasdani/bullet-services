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

              # Void (delete) invoice in FreshBooks
              if freshbooks_invoice&.freshbooks_id.present?
                invoices_client.void(freshbooks_invoice.freshbooks_id)

                # Sync from FreshBooks to get the updated status
                # This will trigger propagate_status_to_invoice callback which sets status to "voided"
                sleep(0.5)
                freshbooks_invoice.sync_from_freshbooks
                freshbooks_invoice.reload
              end

              # Send voidance email from Rails (not FreshBooks)
              InvoiceMailer.with(
                invoice: invoice,
                client_email: client_email
              ).voided_invoice_email.deliver_now

              # Update local invoice status to indicate email was sent
              # Use update_columns to skip callbacks and prevent sync from overwriting our status
              # This must happen AFTER the sync/callback to ensure our status persists
              invoice.reload
              invoice.update_columns(
                status: 'voided + email sent',
                final_status: 'voided + email sent',
                updated_at: Time.current
              )

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

            unless freshbooks_invoice
              flash[:error] = 'No FreshBooks invoice found for this invoice'
              redirect_back(fallback_location: fallback_path)
              next
            end

            begin
              DiscountHelper.apply_discount_to_invoice(invoice, freshbooks_invoice, fallback_path, flash)
              flash[:success] = '10% discount applied successfully' unless flash[:error]
            rescue StandardError => e
              Rails.logger.error("Failed to apply discount: #{e.message}")
              Rails.logger.error(e.backtrace.first(5).join("\n"))
              flash[:error] = "Failed to apply discount: #{e.message}"
            end

            redirect_back(fallback_location: fallback_path)
          end
        end
      end

      # Helper module for discount application logic
      module DiscountHelper
        DISCOUNT_PERCENTAGE = 0.10
        VAT_RATE = 1.20

        module_function

        def apply_discount_to_invoice(invoice, freshbooks_invoice, fallback_path, flash)
          invoices_client = Freshbooks::Invoices.new
          current_invoice = InvoiceFetcher.fetch(invoices_client, freshbooks_invoice, flash)
          return unless current_invoice

          invoice_lines = LinePreparer.prepare(invoice, current_invoice, fallback_path, flash)
          return unless invoice_lines

          lines = LineBuilder.build(invoice_lines, current_invoice)
          total_amount = LineCalculator.total(lines)

          unless total_amount.positive?
            flash[:error] = 'Invoice total is zero. Cannot apply discount.'
            return
          end

          lines << DiscountLineBuilder.build(total_amount, current_invoice)
          InvoiceUpdater.update(invoices_client, freshbooks_invoice, current_invoice, invoice, lines)
          AmountSyncer.sync(invoices_client, freshbooks_invoice, invoice)
        end
      end

      # Handles fetching invoice data from FreshBooks
      module InvoiceFetcher
        module_function

        def fetch(invoices_client, freshbooks_invoice, flash)
          current_invoice = invoices_client.get(freshbooks_invoice.freshbooks_id)
          flash[:error] = 'Could not retrieve invoice from FreshBooks' unless current_invoice
          current_invoice
        end
      end

      # Handles preparing and reconstructing invoice lines
      module LinePreparer
        module_function

        def prepare(invoice, current_invoice, _fallback_path, flash)
          invoice_lines = filter_existing_discounts(current_invoice['lines'] || [])

          if invoice_lines.empty?
            invoice_lines = LineReconstructor.reconstruct(invoice, current_invoice, flash)
            return nil unless invoice_lines
          end

          invoice_lines
        end

        def filter_existing_discounts(lines)
          lines.reject { |line| line['name']&.downcase&.include?('discount') }
        end
      end

      # Handles reconstructing line items from invoice amount
      module LineReconstructor
        module_function

        def reconstruct(invoice, current_invoice, flash)
          amount_data = current_invoice['amount'] || {}
          invoice_amount = AmountExtractor.extract(amount_data)

          if invoice_amount.zero?
            flash[:error] = 'Invoice has no line items and amount is zero. Cannot apply discount.'
            return nil
          end

          currency_code = CurrencyExtractor.extract(amount_data, current_invoice)
          build_line_item(invoice, current_invoice, invoice_amount, currency_code)
        end

        def build_line_item(invoice, current_invoice, invoice_amount, currency_code)
          [{
            'name' => invoice.name || current_invoice['description'] || 'Invoice Item',
            'description' => invoice.job || invoice.wrs_link || current_invoice['notes'] || '',
            'qty' => 1,
            'unit_cost' => { 'amount' => invoice_amount.to_s, 'code' => currency_code },
            'type' => 0
          }]
        end
      end

      # Extracts amount values from FreshBooks data structures
      module AmountExtractor
        module_function

        def extract(amount_data)
          return 0.0 unless amount_data

          amount_data.is_a?(Hash) ? amount_data['amount'].to_f : amount_data.to_f
        end
      end

      # Extracts currency codes from FreshBooks data structures
      module CurrencyExtractor
        module_function

        def extract(amount_data, current_invoice)
          if amount_data.is_a?(Hash)
            amount_data['code'] || current_invoice['currency_code'] || 'USD'
          else
            current_invoice['currency_code'] || 'USD'
          end
        end
      end

      # Builds line items for FreshBooks API
      module LineBuilder
        module_function

        def build(invoice_lines, current_invoice)
          invoice_lines.map do |line|
            unit_cost = UnitCostExtractor.extract(line)
            quantity = (line['qty'] || line['quantity'] || 1).to_f
            LineItemBuilder.build(line, unit_cost, quantity, current_invoice)
          end
        end
      end

      # Extracts unit cost from line data
      module UnitCostExtractor
        module_function

        def extract(line)
          unit_cost_data = line['unit_cost'] || {}
          cost_value = unit_cost_data.is_a?(Hash) ? unit_cost_data['amount'] : unit_cost_data
          cost_value.to_f
        end
      end

      # Builds individual line item hash
      module LineItemBuilder
        module_function

        def build(line, unit_cost, quantity, current_invoice)
          currency = CurrencyExtractor.extract_from_line(line, current_invoice)
          line_item = build_base(line, unit_cost, quantity, currency)
          TaxAttributeAdder.add(line_item, line, current_invoice)
          line_item
        end

        def build_base(line, unit_cost, quantity, currency)
          {
            name: line['name'],
            description: line['description'],
            quantity: quantity.to_i,
            cost: unit_cost,
            currency: currency,
            type: line['type'] || 0
          }
        end
      end

      # Extracts currency from line data
      module CurrencyExtractor
        module_function

        def extract_from_line(line, current_invoice)
          unit_cost_data = line['unit_cost'] || {}
          currency = unit_cost_data.is_a?(Hash) ? unit_cost_data['code'] : nil
          currency || current_invoice['currency_code'] || 'USD'
        end
      end

      # Adds tax attributes to line items
      module TaxAttributeAdder
        module_function

        def add(line_item, line, current_invoice)
          line_item[:tax_amount1] = line['tax_amount1'] if line['tax_amount1'].present?
          line_item[:tax_amount2] = line['tax_amount2'] if line['tax_amount2'].present?

          tax_included = TaxIncludedDeterminer.determine(line, current_invoice)
          line_item[:tax_included] = tax_included if tax_included
        end
      end

      # Determines if tax is included
      module TaxIncludedDeterminer
        module_function

        def determine(line, current_invoice)
          line['tax_included'].present? ? line['tax_included'] : current_invoice['tax_included'] == 'yes'
        end
      end

      # Calculates totals from line items
      module LineCalculator
        module_function

        def total(lines)
          lines.sum { |line| line[:cost] * line[:quantity] }
        end
      end

      # Builds discount line item
      module DiscountLineBuilder
        module_function

        def build(total_amount, current_invoice)
          discount_amount = total_amount * DiscountHelper::DISCOUNT_PERCENTAGE

          {
            name: '10% Discount',
            description: 'Applied 10% discount',
            quantity: 1,
            cost: -discount_amount.round(2),
            currency: current_invoice['currency_code'] || 'USD',
            type: 0,
            tax_included: current_invoice['tax_included'] == 'yes'
          }
        end
      end

      # Updates invoice in FreshBooks
      module InvoiceUpdater
        module_function

        def update(invoices_client, freshbooks_invoice, current_invoice, invoice, lines)
          invoices_client.update(
            freshbooks_invoice.freshbooks_id,
            client_id: current_invoice['customerid'] || invoice.freshbooks_client_id,
            currency: current_invoice['currency_code'] || 'USD',
            lines: lines
          )
        end
      end

      # Syncs invoice amounts from FreshBooks to local database
      module AmountSyncer
        module_function

        def sync(invoices_client, freshbooks_invoice, invoice)
          sleep(0.5) # Allow FreshBooks to process the update
          freshbooks_invoice.sync_from_freshbooks
          freshbooks_invoice.reload

          updated_invoice = invoices_client.get(freshbooks_invoice.freshbooks_id)
          amounts = AmountCalculator.calculate(updated_invoice, freshbooks_invoice)

          invoice.update_columns(
            excluded_vat_amount: amounts[:excluded].round(2),
            included_vat_amount: amounts[:included].round(2),
            updated_at: Time.current
          )
        end
      end

      # Calculates VAT amounts from FreshBooks data
      module AmountCalculator
        module_function

        def calculate(updated_invoice, freshbooks_invoice)
          if updated_invoice
            amount_data = updated_invoice['amount'] || {}
            total_amount = AmountExtractor.extract(amount_data)

            # FreshBooks always returns amounts with VAT included
            { included: total_amount, excluded: total_amount / DiscountHelper::VAT_RATE }
          else
            # Fallback: use synced amount from freshbooks_invoice record
            excluded = freshbooks_invoice.amount || 0
            { excluded: excluded, included: excluded * DiscountHelper::VAT_RATE }
          end
        end
      end
    end
  end
end
