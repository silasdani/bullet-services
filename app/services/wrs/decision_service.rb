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

        attach_pdf_to_invoice(invoice, result) if result.is_a?(Hash)

        mark_wrs_as_approved!
        send_admin_accept_email!(invoice, fb_client)
      end
    end

    def attach_pdf_to_invoice(invoice, result)
      if result[:pdf_base64].present?
        attach_pdf_from_base64(invoice, result[:pdf_base64])
      elsif result[:pdf_url].present?
        attach_pdf_from_url(invoice, result[:pdf_url])
      else
        log_warn("No PDF data available in result: #{result.inspect}")
      end
    end

    def attach_pdf_from_base64(invoice, base64_data)
      log_info("Attempting to attach PDF from base64 data (length: #{base64_data.length})")
      attach_invoice_pdf_from_base64!(invoice, base64_data)
    end

    def attach_pdf_from_url(invoice, pdf_url)
      if ui_route?(pdf_url)
        log_ui_route_skip(pdf_url)
      else
        log_info("Attempting to attach PDF from URL: #{pdf_url}")
        attach_invoice_pdf!(invoice, pdf_url)
      end
    end

    def ui_route?(pdf_url)
      pdf_url.include?('/#/') || pdf_url.include?('/invoice/')
    end

    def log_ui_route_skip(pdf_url)
      log_warn("Skipping PDF download from UI route (will return HTML): #{pdf_url}")
      log_info('Users can download PDF directly from FreshBooks using the invoice_pdf_link')
    end

    def handle_decline
      with_error_handling do
        mark_wrs_as_rejected!
        send_admin_decline_email!
      end
    end

    def ensure_freshbooks_client!
      clients_client = Freshbooks::Clients.new

      existing_client = find_existing_client(clients_client)
      return existing_client if existing_client

      create_new_freshbooks_client(clients_client)
    end

    def find_existing_client(clients_client)
      fb_client_record = FreshbooksClient.find_by(email: email)
      return nil unless fb_client_record

      clients_client.get(fb_client_record.freshbooks_id)
    end

    def create_new_freshbooks_client(clients_client)
      created = clients_client.create(build_client_creation_params)
      fb_id = extract_client_id(created)
      client_record = create_local_client_record(created, fb_id)

      log_info("Created FreshbooksClient record: ID=#{client_record.id}, freshbooks_id=#{fb_id}, email=#{email}")

      created
    end

    def build_client_creation_params
      {
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
      }
    end

    def extract_client_id(created)
      created['id'] || created['clientid']
    end

    def create_local_client_record(created, fb_id)
      FreshbooksClient.create!(
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
      begin
        pdf_bytes = decode_and_validate_pdf(base64_data)
        return unless pdf_bytes

        tempfile = create_pdf_tempfile(pdf_bytes)
        attach_pdf_with_retries(invoice, tempfile)
      rescue StandardError => e
        log_error("Failed to attach PDF from base64: #{e.message}")
        log_error("Error class: #{e.class}")
        log_error("Backtrace: #{e.backtrace.first(10).join('\n')}")
      ensure
        cleanup_tempfile(tempfile)
      end
    end

    def decode_and_validate_pdf(base64_data)
      log_info("Decoding base64 PDF data (length: #{base64_data.length})")
      pdf_bytes = Base64.decode64(base64_data)
      log_info("Decoded PDF bytes length: #{pdf_bytes.length}")

      return pdf_bytes if pdf_bytes.start_with?('%PDF')

      log_invalid_pdf_error(pdf_bytes)
      nil
    rescue StandardError => e
      log_error("Failed to decode base64 PDF data: #{e.message}")
      nil
    end

    def log_invalid_pdf_error(pdf_bytes)
      first_bytes = safe_read_first_bytes(pdf_bytes)
      log_error('Base64 data does not appear to be a valid PDF')
      log_error("First bytes: #{first_bytes.inspect}")
    end

    def safe_read_first_bytes(pdf_bytes)
      pdf_bytes[0..20]
    rescue StandardError
      'unable to read'
    end

    def create_pdf_tempfile(pdf_bytes)
      tempfile = Tempfile.new(['invoice_pdf', '.pdf'], binmode: true)
      tempfile.write(pdf_bytes)
      tempfile.rewind
      log_info('Created tempfile with PDF data')
      tempfile
    end

    def attach_pdf_with_retries(invoice, tempfile)
      invoice.reload if invoice.persisted?

      max_retries = 3
      retry_count = 0
      attachment_success = false

      while retry_count < max_retries && !attachment_success
        attachment_success = attempt_pdf_attachment(invoice, tempfile, retry_count, max_retries)
        retry_count += 1 unless attachment_success
      end

      log_info("Successfully attached PDF from base64 data to invoice #{invoice.id}") if attachment_success
    rescue StandardError => e
      log_error("Failed to attach PDF after #{retry_count} retries: #{e.message}")
      log_error("Error class: #{e.class}")
      raise
    end

    def attempt_pdf_attachment(invoice, tempfile, retry_count, max_retries)
      invoice.invoice_pdf.attach(build_attachment_params(invoice, tempfile))
      verify_and_log_attachment(invoice)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      handle_attachment_error(e, tempfile, retry_count, max_retries)
      false
    end

    def build_attachment_params(invoice, tempfile)
      {
        io: tempfile.dup,
        filename: "invoice_#{invoice.slug}_#{Time.current.to_i}.pdf",
        content_type: 'application/pdf',
        metadata: { source: 'freshbooks_api_base64' }
      }
    end

    def verify_and_log_attachment(invoice)
      invoice.reload
      return false unless invoice.invoice_pdf.attached?

      blob = invoice.invoice_pdf.blob
      log_info("PDF attachment verified: #{blob.filename}, size: #{blob.byte_size} bytes")
      true
    end

    def handle_attachment_error(error, tempfile, retry_count, max_retries)
      raise if retry_count >= max_retries - 1

      log_warn("Attachment error: #{error.message}, retrying (#{retry_count + 1}/#{max_retries})...")
      sleep(0.5)
      tempfile&.rewind
    end

    def cleanup_tempfile(tempfile)
      return unless tempfile

      tempfile.close
    rescue StandardError
      nil
    ensure
      begin
        tempfile&.unlink
      rescue StandardError
        nil
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
      subject = build_accept_email_subject(invoice, fb_client_data)
      html_body = build_accept_email_body

      send_email(subject, html_body)
    end

    def build_accept_email_subject(invoice, fb_client_data)
      invoice_id = invoice_identifier(invoice, fb_client_data)
      address = "#{window_schedule_repair.address} Flat #{window_schedule_repair.flat_number}"
      "ACTION REQUIRED | Invoice #{invoice_id} for #{address}"
    end

    def build_accept_email_body
      <<~HTML
        <h2>New WRS Acceptance and Invoice Created</h2>
        <p><strong>Client:</strong> #{client_full_name}</p>
        <p><strong>Email:</strong> #{email}</p>
        <p><strong>Address:</strong> #{window_schedule_repair.address} Flat #{window_schedule_repair.flat_number}</p>
        <p><strong>WRS Reference:</strong> #{window_schedule_repair.reference_number}</p>
        <p><strong>WRS Link:</strong> <a href="#{wrs_public_url}">#{wrs_public_url}</a></p>
        <p><strong>Invoice total (incl. VAT):</strong> #{window_schedule_repair.total_vat_included_price}</p>
      HTML
    end

    def send_admin_decline_email!
      subject = build_decline_email_subject
      html_body = build_decline_email_body

      send_email(subject, html_body)
    end

    def build_decline_email_subject
      address = "#{window_schedule_repair.address} Flat #{window_schedule_repair.flat_number}"
      "ACTION REQUIRED | WRS declined for #{address}"
    end

    def build_decline_email_body
      <<~HTML
        <h2>WRS Declined by Client</h2>
        <p><strong>Client:</strong> #{client_full_name}</p>
        <p><strong>Email:</strong> #{email}</p>
        <p><strong>Address:</strong> #{window_schedule_repair.address} Flat #{window_schedule_repair.flat_number}</p>
        <p><strong>WRS Reference:</strong> #{window_schedule_repair.reference_number}</p>
        <p><strong>WRS Link:</strong> <a href="#{wrs_public_url}">#{wrs_public_url}</a></p>
      HTML
    end

    def send_email(subject, html_body)
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
