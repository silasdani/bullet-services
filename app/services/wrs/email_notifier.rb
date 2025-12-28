# frozen_string_literal: true

module Wrs
  # Service for sending admin notification emails for WRS decisions
  class EmailNotifier
    def initialize(window_schedule_repair, first_name, last_name, email)
      @window_schedule_repair = window_schedule_repair
      @first_name = first_name
      @last_name = last_name
      @email = email
    end

    def send_accept_email(invoice, fb_client_data)
      subject = build_accept_email_subject(invoice, fb_client_data)
      html_body = build_accept_email_body

      send_email(subject, html_body)
    end

    def send_decline_email
      subject = build_decline_email_subject
      html_body = build_decline_email_body

      send_email(subject, html_body)
    end

    private

    attr_reader :window_schedule_repair, :first_name, :last_name, :email

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
      ConfigHelper.get_config(
        key: :admin_email,
        env_key: 'ADMIN_EMAIL',
        default: ConfigHelper.get_config(
          key: :contact_email,
          env_key: 'CONTACT_EMAIL',
          default: 'office@bulletservices.co.uk'
        )
      )
    end

    def client_full_name
      [first_name, last_name].compact.join(' ')
    end

    def wrs_public_url
      host = ENV.fetch('PUBLIC_APP_HOST', 'bulletservices.co.uk')
      "#{host}/wrs/#{window_schedule_repair.slug}"
    end

    def invoice_identifier(invoice, _fb_client_data)
      fb_invoice = invoice.freshbooks_invoices.last
      fb_invoice&.invoice_number || invoice.slug
    end
  end
end
