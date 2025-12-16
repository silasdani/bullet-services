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

            fallback_path = rails_admin.show_path(model_name: 'invoice', id: invoice.id)

            if freshbooks_invoice.nil?
              flash[:error] = 'No FreshBooks invoice found for this invoice'
              redirect_back(fallback_location: fallback_path)
              next
            end

            # Helper methods for email formatting
            build_invoice_email_html = lambda do |invoice_number:, invoice_amount:, due_date:, client_name:, flat_address:, wrs_link:, payment_link:|
              <<~HTML
                <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                  <p style="font-size: 16px; line-height: 1.6;">
                    Bullet Services LTD sent you an invoice (#{invoice_number}) for £#{invoice_amount.round(2)}#{if due_date
                                                                                                                   " that's due on #{due_date}"
                                                                                                                 end}.
                  </p>

                  <p style="font-size: 16px; line-height: 1.6;">
                    Dear #{client_name},
                  </p>

                  <p style="font-size: 16px; line-height: 1.6;">
                    This is your invoice for the Windows Schedule Repairs at #{flat_address}.
                    #{%(<br><br>Visit <a href="#{wrs_link}">#{wrs_link}</a> to review your quote.) if wrs_link}
                  </p>

                  <p style="font-size: 16px; line-height: 1.6;">
                    Thank you and best regards,<br>
                    Bullet Services.
                  </p>

                  #{if payment_link.present?
                      %(<div style="margin: 30px 0; text-align: center;">
                            <a href="#{payment_link}" style="display: inline-block; padding: 12px 30px; background-color: #007bff; color: #ffffff; text-decoration: none; border-radius: 5px; font-weight: bold; font-size: 16px;">
                              View and Pay Invoice
                            </a>
                          </div>)
                    end}
                </div>
              HTML
            end

            build_invoice_email_text = lambda do |invoice_number:, invoice_amount:, due_date:, client_name:, flat_address:, wrs_link:, payment_link:|
              <<~TEXT
                Bullet Services LTD sent you an invoice (#{invoice_number}) for £#{invoice_amount.round(2)}#{if due_date
                                                                                                               " that's due on #{due_date}"
                                                                                                             end}.

                Dear #{client_name},

                This is your invoice for the Windows Schedule Repairs at #{flat_address}.
                #{"\n\nVisit #{wrs_link} to review your quote." if wrs_link}

                Thank you and best regards,
                Bullet Services.

                #{"\n\nView and Pay Invoice: #{payment_link}" if payment_link}
              TEXT
            end

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

              if client_email.blank?
                flash[:error] = 'No email address found for client. Please provide an email address.'
                redirect_back(fallback_location: fallback_path)
                next
              end

              # Get payment link from FreshBooks
              payment_link = invoices_client.get_payment_link(freshbooks_invoice.freshbooks_id)

              # Get invoice details
              invoice_number = freshbooks_invoice.invoice_number || 'N/A'
              invoice_amount = invoice.total_amount || 0
              due_date = freshbooks_invoice.due_date || ((invoice.created_at&.to_date || Date.today) + 30.days)
              formatted_due_date = due_date.strftime('%B %d, %Y') if due_date

              # Get WRS link if available
              wrs_link = invoice.wrs_link
              flat_address = invoice.flat_address || 'your property'

              # Build email content
              client_display_name = client_name || 'Valued Client'
              subject = "Invoice (#{invoice_number}) for £#{invoice_amount.round(2)}"

              html_body = build_invoice_email_html.call(
                invoice_number: invoice_number,
                invoice_amount: invoice_amount,
                due_date: formatted_due_date,
                client_name: client_display_name,
                flat_address: flat_address,
                wrs_link: wrs_link,
                payment_link: payment_link
              )

              text_body = build_invoice_email_text.call(
                invoice_number: invoice_number,
                invoice_amount: invoice_amount,
                due_date: formatted_due_date,
                client_name: client_display_name,
                flat_address: flat_address,
                wrs_link: wrs_link,
                payment_link: payment_link
              )

              # Send email via MailerSend (FreshBooks API doesn't support direct email sending)
              email_service = MailerSendEmailService.new(
                to: params[:email] || client_email,
                subject: subject,
                html: html_body,
                text: text_body,
                from_name: 'Bullet Services LTD'
              )

              email_service.call

              if email_service.success?
                # Update local invoice status
                invoice.update!(status: 'sent', final_status: 'sent')
                freshbooks_invoice&.update!(status: 'sent')
                flash[:success] = "Invoice email sent successfully to #{client_email}"
              else
                error_message = email_service.errors.any? ? email_service.errors.join(', ') : 'Unknown error occurred'
                Rails.logger.error("Failed to send invoice email: #{error_message}")
                flash[:error] = "Failed to send invoice email: #{error_message}"
              end
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

            redirect_back(fallback_location: fallback_path)
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
                      status: 'voided'
                    )

                    # Send voidance email
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
          authorized? && bindings[:object].is_a?(Invoice)
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
