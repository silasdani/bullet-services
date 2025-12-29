# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/invoice_mailer
class InvoiceMailerPreview < ActionMailer::Preview
  def invoice_email
    invoice = create_sample_invoice

    InvoiceMailer.with(
      invoice: invoice,
      client_email: 'client@example.com',
      client_name: 'John Doe',
      payment_link: 'https://bulletservices.co.uk/pay/inv-2024-001'
    ).invoice_email
  end

  def voided_invoice_email
    invoice = create_sample_invoice

    InvoiceMailer.with(
      invoice: invoice,
      client_email: 'client@example.com'
    ).voided_invoice_email
  end

  private

  def create_sample_invoice
    # Try to use existing invoice from database, otherwise create a mock
    invoice = Invoice.first

    if invoice.present?
      # Mock wrs_link if not already defined
      unless invoice.respond_to?(:wrs_link)
        invoice.define_singleton_method(:wrs_link) do
          'https://bulletservices.co.uk/wrs/sample-slug'
        end
      end
      return invoice
    end

    # Create a mock invoice for preview
    invoice = Invoice.new(
      slug: 'inv-2024-001',
      total_amount: 1250.00,
      flat_address: '123 Main Street, Flat 4A',
      created_at: Date.today
    )

    # Mock wrs_link method
    invoice.define_singleton_method(:wrs_link) do
      'https://bulletservices.co.uk/wrs/sample-slug'
    end

    # Mock freshbooks_invoices association
    fb_invoice = OpenStruct.new(
      invoice_number: 'INV-2024-001',
      due_date: Date.today + 30.days
    )
    invoice.define_singleton_method(:freshbooks_invoices) do
      OpenStruct.new(last: fb_invoice)
    end

    invoice
  end
end
