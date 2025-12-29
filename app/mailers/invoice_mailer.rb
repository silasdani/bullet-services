# frozen_string_literal: true

class InvoiceMailer < ApplicationMailer
  def invoice_email
    @invoice = params[:invoice]
    @freshbooks_invoice = @invoice.freshbooks_invoices.last
    @invoice_number = @freshbooks_invoice&.invoice_number || @invoice.slug
    @invoice_amount = format_amount(@invoice.total_amount || 0)
    @due_date = format_due_date(@freshbooks_invoice&.due_date || ((@invoice.created_at&.to_date || Date.today) + 30.days))
    @client_name = params[:client_name] || 'Valued Client'
    @flat_address = @invoice.flat_address || 'your property'
    @wrs_link = @invoice.wrs_link
    @payment_link = params[:payment_link]

    mail(
      to: params[:client_email],
      subject: "Invoice (#{@invoice_number}) for #{@invoice_amount}",
      from: "#{ENV.fetch('MAILERSEND_FROM_NAME',
                         'Bullet Services')} <#{ENV.fetch('MAILERSEND_FROM_EMAIL', 'no-reply@example.com')}>"
    )
  end

  def voided_invoice_email
    @invoice = params[:invoice]
    @freshbooks_invoice = @invoice.freshbooks_invoices.last
    @invoice_number = @freshbooks_invoice&.invoice_number || @invoice.slug
    @address = @invoice.flat_address || 'your property'
    @wrs_link = @invoice.wrs_link
    @submission_date = (@invoice.created_at&.to_date || Date.today).strftime('%B %d, %Y')

    mail(
      to: params[:client_email],
      subject: 'Windows Schedule Repairs Invoice'
    )
  end

  private

  def format_amount(amount)
    "£#{amount.round(2)}"
  end

  def format_due_date(due_date)
    return 'N/A' unless due_date

    due_date.strftime('%B %d, %Y')
  end
end
