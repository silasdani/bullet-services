# frozen_string_literal: true

class WrsMailer < ApplicationMailer
  def wrs_accept_notification
    @window_schedule_repair = params[:window_schedule_repair]
    assign_wrs_variables
    assign_client_variables

    mail(
      to: admin_email,
      subject: "ACTION REQUIRED | Invoice #{@invoice_number} for #{@address}"
    )
  end

  def wrs_decline_notification
    @window_schedule_repair = params[:window_schedule_repair]
    @first_name = params[:first_name]
    @last_name = params[:last_name]
    @email = params[:email]
    @address = "#{@window_schedule_repair.address} Flat #{@window_schedule_repair.flat_number}"
    @reference_number = @window_schedule_repair.reference_number
    @wrs_link = wrs_public_url(@window_schedule_repair)

    mail(
      to: admin_email,
      subject: "ACTION REQUIRED | WRS declined for #{@address}"
    )
  end

  private

  def assign_wrs_variables
    @invoice = params[:invoice]
    @invoice_number = invoice_identifier(@invoice, params[:fb_client_data])
    @address = "#{@window_schedule_repair.address} Flat #{@window_schedule_repair.flat_number}"
    @wrs_link = wrs_public_url(@window_schedule_repair)
    @total_price = @window_schedule_repair.total_vat_included_price
  end

  def assign_client_variables
    @first_name = params[:first_name]
    @last_name = params[:last_name]
    @email = params[:email]
  end

  def admin_email
    ENV.fetch('ADMIN_EMAIL', 'danielsilas32@gmail.com')
  end

  def wrs_public_url(window_schedule_repair)
    host = ENV.fetch('PUBLIC_APP_HOST', 'bulletservices.co.uk')
    protocol = ENV.fetch('PUBLIC_APP_PROTOCOL', 'https')
    "#{protocol}://#{host}/wrs/#{window_schedule_repair.slug}"
  end

  def invoice_identifier(invoice, _fb_client_data)
    fb_invoice = invoice.freshbooks_invoices.last
    fb_invoice&.invoice_number || invoice.slug
  end
end
