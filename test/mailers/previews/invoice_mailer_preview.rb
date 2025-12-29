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
    invoice = Invoice.first
    return mock_existing_invoice(invoice) if invoice.present?

    create_mock_invoice
  end

  def mock_existing_invoice(invoice)
    return invoice if invoice.respond_to?(:wrs_link)

    invoice.define_singleton_method(:wrs_link) do
      'https://bulletservices.co.uk/wrs/sample-slug'
    end
    invoice
  end

  def create_mock_invoice
    invoice = Invoice.new(
      slug: 'inv-2024-001',
      total_amount: 1250.00,
      flat_address: '123 Main Street, Flat 4A',
      created_at: Date.today
    )

    mock_invoice_methods(invoice)
    invoice
  end

  def mock_invoice_methods(invoice)
    invoice.define_singleton_method(:wrs_link) do
      'https://bulletservices.co.uk/wrs/sample-slug'
    end

    fb_invoice = create_mock_fb_invoice
    invoice.define_singleton_method(:freshbooks_invoices) do
      create_association_mock(fb_invoice)
    end
  end

  def create_mock_fb_invoice
    mock = Object.new
    mock.define_singleton_method(:invoice_number) { 'INV-2024-001' }
    mock.define_singleton_method(:due_date) { Date.today + 30.days }
    mock
  end

  def create_association_mock(fb_invoice)
    mock = Object.new
    mock.define_singleton_method(:last) { fb_invoice }
    mock
  end
end
