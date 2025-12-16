# frozen_string_literal: true

module Wrs
  # Handles client accept/decline decisions coming from the public WRS page.
  # On accept:
  # - ensures a FreshBooks client exists
  # - creates a Rails Invoice linked to the WRS
  # - creates a FreshBooks invoice with the correct line item and terms
  # - mirrors the FreshBooks PDF into Active Storage
  # - notifies the admin
  #
  # On decline:
  # - notifies the admin
  # - optionally updates the WRS status
  class DecisionService < BaseService
    attribute :window_schedule_repair
    attribute :first_name, :string
    attribute :last_name, :string
    attribute :email, :string
    attribute :decision, :string

    def call
      return add_error('WRS is required') if window_schedule_repair.nil?
      return add_error('Decision is required') if decision.blank?

      case decision.to_s
      when 'accept'
        handle_accept
      when 'decline'
        handle_decline
      else
        add_error('Invalid decision')
      end
    end

    private

    def handle_accept
      with_error_handling do
        fb_client = ensure_freshbooks_client!
        invoice = create_local_invoice!(fb_client)
        result = create_freshbooks_invoice!(invoice, fb_client)

        if result.is_a?(Hash)
          if result[:pdf_base64].present?
            log_info("Attempting to attach PDF from base64 data (length: #{result[:pdf_base64].length})")
            attach_invoice_pdf_from_base64!(invoice, result[:pdf_base64])
          elsif result[:pdf_url].present?
            # Only try URL download if it's not a UI route (UI routes return HTML)
            if result[:pdf_url].include?('/#/') || result[:pdf_url].include?('/invoice/')
              log_warn("Skipping PDF download from UI route (will return HTML): #{result[:pdf_url]}")
              log_info('Users can download PDF directly from FreshBooks using the invoice_pdf_link')
            else
              log_info("Attempting to attach PDF from URL: #{result[:pdf_url]}")
              attach_invoice_pdf!(invoice, result[:pdf_url])
            end
          else
            log_warn("No PDF data available in result: #{result.inspect}")
          end
        else
          log_warn("Result is not a hash: #{result.inspect}")
        end

        mark_wrs_as_approved!
        send_admin_accept_email!(invoice, fb_client)
      end
    end

    def handle_decline
      with_error_handling do
        mark_wrs_as_rejected!
        send_admin_decline_email!
      end
    end

    def ensure_freshbooks_client!
      clients_client = Freshbooks::Clients.new

      # Try to find an existing FreshBooksClient record by email
      fb_client_record = FreshbooksClient.find_by(email: email)
      if fb_client_record
        fb_client_data = clients_client.get(fb_client_record.freshbooks_id)
        return fb_client_data if fb_client_data
      end

      # Otherwise, create a new FreshBooks client
      created = clients_client.create(
        email: email,
        first_name: first_name,
        last_name: last_name,
        organization: nil,
        phone: nil,
        address: primary_street,
        city: 'London',
        province: nil,
        postal_code: building&.zipcode,
        country: building&.country || 'UK'
      )

      fb_id = created['id'] || created['clientid']

      client_record = FreshbooksClient.create!(
        freshbooks_id: fb_id,
        email: email,
        first_name: first_name,
        last_name: last_name,
        address: primary_street,
        city: 'London',
        postal_code: building&.zipcode,
        country: building&.country || 'UK',
        raw_data: created
      )

      log_info("Created FreshbooksClient record: ID=#{client_record.id}, freshbooks_id=#{fb_id}, email=#{email}")

      created
    end

    def create_local_invoice!(fb_client_data)
      fb_client_id = fb_client_data['id'] || fb_client_data['clientid']

      Invoice.create!(
        name: 'Flat | Windows Schedule Repairs',
        slug: generate_invoice_slug,
        freshbooks_client_id: fb_client_id,
        window_schedule_repair_id: window_schedule_repair.id,
        wrs_link: wrs_public_url,
        included_vat_amount: window_schedule_repair.total_vat_included_price,
        excluded_vat_amount: window_schedule_repair.total_vat_excluded_price,
        status: 'pending',
        final_status: 'draft',
        flat_address: flat_address,
        generated_by: 'wrs_form'
      )
    end

    def create_freshbooks_invoice!(invoice, fb_client_data)
      fb_client_id = fb_client_data['id'] || fb_client_data['clientid']

      lines = [
        {
          name: 'Flat | Windows Schedule Repairs',
          description: "Visit #{wrs_public_url} to view the complete description of the items.",
          quantity: 1,
          cost: window_schedule_repair.total_vat_included_price || 0,
          type: 0,
          tax_included: true # Explicitly mark that VAT is already included in the cost
        }
      ]

      invoice.create_in_freshbooks!(
        client_id: fb_client_id,
        lines: lines,
        send_email: false
      )
    end

    def attach_invoice_pdf!(invoice, pdf_url)
      return if pdf_url.blank?

      Webflow::PdfMirrorService.new(
        record: invoice,
        source_url: pdf_url,
        attachment_name: :invoice_pdf
      ).call
    end

    def attach_invoice_pdf_from_base64!(invoice, base64_data)
      return if base64_data.blank?

      tempfile = nil
      max_retries = 3
      retry_count = 0

      begin
        log_info("Decoding base64 PDF data (length: #{base64_data.length})")

        # Decode base64 PDF data
        pdf_bytes = Base64.decode64(base64_data)
        log_info("Decoded PDF bytes length: #{pdf_bytes.length}")

        # Validate it's actually PDF (starts with %PDF)
        unless pdf_bytes.start_with?('%PDF')
          first_bytes = begin
            pdf_bytes[0..20]
          rescue StandardError
            'unable to read'
          end
          log_error('Base64 data does not appear to be a valid PDF')
          log_error("First bytes: #{first_bytes.inspect}")
          return
        end

        # Retry loop for attachment
        begin
          # Create a tempfile with the PDF bytes
          tempfile = Tempfile.new(['invoice_pdf', '.pdf'], binmode: true)
          tempfile.write(pdf_bytes)
          tempfile.rewind
          log_info('Created tempfile with PDF data')

          # Reload invoice to ensure we have latest state
          invoice.reload if invoice.persisted?

          # Attach to invoice with retry logic
          attachment_success = false
          while retry_count < max_retries && !attachment_success
            begin
              invoice.invoice_pdf.attach(
                io: tempfile.dup, # Use dup to avoid closed stream errors
                filename: "invoice_#{invoice.slug}_#{Time.current.to_i}.pdf",
                content_type: 'application/pdf',
                metadata: { source: 'freshbooks_api_base64' }
              )

              # Verify attachment immediately
              invoice.reload
              if invoice.invoice_pdf.attached?
                blob = invoice.invoice_pdf.blob
                log_info("PDF attachment verified: #{blob.filename}, size: #{blob.byte_size} bytes")
                attachment_success = true
              else
                retry_count += 1
                if retry_count < max_retries
                  log_warn("Attachment verification failed, retrying (#{retry_count}/#{max_retries})...")
                  sleep(0.5) # Brief delay before retry
                else
                  log_error('PDF attachment failed - file not attached after all retries')
                end
              end
            rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
              retry_count += 1
              raise unless retry_count < max_retries

              log_warn("Attachment error: #{e.message}, retrying (#{retry_count}/#{max_retries})...")
              sleep(0.5)
              tempfile&.rewind
            end
          end

          log_info("Successfully attached PDF from base64 data to invoice #{invoice.id}") if attachment_success
        rescue StandardError => e
          log_error("Failed to attach PDF after #{retry_count} retries: #{e.message}")
          log_error("Error class: #{e.class}")
          raise
        end
      rescue StandardError => e
        log_error("Failed to attach PDF from base64: #{e.message}")
        log_error("Error class: #{e.class}")
        log_error("Backtrace: #{e.backtrace.first(10).join('\n')}")
      ensure
        if tempfile
          begin
            tempfile.close
          rescue StandardError
            nil
          end
          begin
            tempfile.unlink
          rescue StandardError
            nil
          end
        end
      end
    end

    def mark_wrs_as_approved!
      window_schedule_repair.update!(
        status: WindowScheduleRepair.statuses[:approved]
      )
    end

    def mark_wrs_as_rejected!
      window_schedule_repair.update!(
        status: WindowScheduleRepair.statuses[:rejected]
      )
    end

    def send_admin_accept_email!(invoice, fb_client_data)
      subject = "ACTION REQUIRED | Invoice #{invoice_identifier(invoice,
                                                                fb_client_data)} for #{window_schedule_repair.address} Flat #{window_schedule_repair.flat_number}"

      html_body = <<~HTML
        <h2>New WRS Acceptance and Invoice Created</h2>
        <p><strong>Client:</strong> #{client_full_name}</p>
        <p><strong>Email:</strong> #{email}</p>
        <p><strong>Address:</strong> #{window_schedule_repair.address} Flat #{window_schedule_repair.flat_number}</p>
        <p><strong>WRS Reference:</strong> #{window_schedule_repair.reference_number}</p>
        <p><strong>WRS Link:</strong> <a href="#{wrs_public_url}">#{wrs_public_url}</a></p>
        <p><strong>Invoice total (incl. VAT):</strong> #{window_schedule_repair.total_vat_included_price}</p>
      HTML

      MailerSendEmailService.new(
        to: admin_email,
        subject: subject,
        html: html_body,
        text: html_body.gsub(%r{</?[^>]*>}, '')
      ).call
    end

    def send_admin_decline_email!
      subject = "ACTION REQUIRED | WRS declined for #{window_schedule_repair.address} Flat #{window_schedule_repair.flat_number}"

      html_body = <<~HTML
        <h2>WRS Declined by Client</h2>
        <p><strong>Client:</strong> #{client_full_name}</p>
        <p><strong>Email:</strong> #{email}</p>
        <p><strong>Address:</strong> #{window_schedule_repair.address} Flat #{window_schedule_repair.flat_number}</p>
        <p><strong>WRS Reference:</strong> #{window_schedule_repair.reference_number}</p>
        <p><strong>WRS Link:</strong> <a href="#{wrs_public_url}">#{wrs_public_url}</a></p>
      HTML

      MailerSendEmailService.new(
        to: admin_email,
        subject: subject,
        html: html_body,
        text: html_body.gsub(%r{</?[^>]*>}, '')
      ).call
    end

    def admin_email
      ENV.fetch('ADMIN_EMAIL', ENV.fetch('CONTACT_EMAIL', 'office@bulletservices.co.uk'))
    end

    def client_full_name
      [first_name, last_name].compact.join(' ')
    end

    def wrs_public_url
      Rails.application.routes.url_helpers.wrs_show_url(
        slug: window_schedule_repair.slug,
        host: ENV.fetch('PUBLIC_APP_HOST', 'bulletservices.co.uk')
      )
    end

    def building
      window_schedule_repair.building
    end

    def primary_street
      building&.street
    end

    def flat_address
      [
        window_schedule_repair.address,
        "Flat #{window_schedule_repair.flat_number}"
      ].compact.join(', ')
    end

    def invoice_identifier(invoice, _fb_client_data)
      fb_invoice = invoice.freshbooks_invoices.last
      fb_invoice&.invoice_number || invoice.slug
    end

    def generate_invoice_slug
      base = "wrs-#{window_schedule_repair.reference_number}-#{Time.current.to_i}"
      base.parameterize
    end
  end
end
