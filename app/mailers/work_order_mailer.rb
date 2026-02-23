# frozen_string_literal: true

class WorkOrderMailer < ApplicationMailer
  def work_order_accept_notification
    @work_order = params[:work_order]
    assign_work_order_variables
    assign_client_variables

    mail(
      to: admin_email,
      bcc: MailerSendEmailService::CONFIRMATION_COPY_EMAILS,
      subject: "ACTION REQUIRED | Invoice #{@invoice_number} for #{@address}"
    )
  end

  def work_order_decline_notification
    @work_order = params[:work_order]
    @first_name = params[:first_name]
    @last_name = params[:last_name]
    @email = params[:email]
    @address = "#{@work_order.address} Flat #{@work_order.flat_number}"
    @reference_number = @work_order.reference_number
    @work_order_link = work_order_public_url(@work_order)

    mail(
      to: admin_email,
      bcc: MailerSendEmailService::CONFIRMATION_COPY_EMAILS,
      subject: "WRS declined for #{@address}"
    )
  end

  private

  def assign_work_order_variables
    @invoice = params[:invoice]
    @invoice_number = invoice_identifier(@invoice, params[:fb_client_data])
    @address = "#{@work_order.address} Flat #{@work_order.flat_number}"
    @work_order_link = work_order_public_url(@work_order)
    @total_price = @work_order.total_vat_included_price
  end

  def assign_client_variables
    @first_name = params[:first_name]
    @last_name = params[:last_name]
    @email = params[:email]
  end

  def admin_email
    ENV.fetch('ADMIN_EMAIL', 'office@bulletservices.co.uk')
  end

  def work_order_public_url(work_order)
    host = ENV.fetch('PUBLIC_APP_HOST', 'bulletservices.co.uk')
    protocol = ENV.fetch('PUBLIC_APP_PROTOCOL', 'https')
    "#{protocol}://#{host}/wrs/#{work_order.slug}"
  end

  def invoice_identifier(invoice, _fb_client_data)
    fb_invoice = invoice.freshbooks_invoices.last
    fb_invoice&.invoice_number || invoice.slug
  end
end
