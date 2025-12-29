# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/wrs_mailer
class WrsMailerPreview < ActionMailer::Preview
  def wrs_accept_notification
    wrs = create_sample_wrs
    invoice = create_sample_invoice(wrs)

    WrsMailer.with(
      window_schedule_repair: wrs,
      first_name: 'John',
      last_name: 'Doe',
      email: 'john.doe@example.com',
      invoice: invoice,
      fb_client_data: {}
    ).wrs_accept_notification
  end

  def wrs_decline_notification
    wrs = create_sample_wrs

    WrsMailer.with(
      window_schedule_repair: wrs,
      first_name: 'Jane',
      last_name: 'Smith',
      email: 'jane.smith@example.com'
    ).wrs_decline_notification
  end

  private

  def create_sample_wrs
    # Try to use existing WRS from database, otherwise create a mock
    wrs = WindowScheduleRepair.first

    return wrs if wrs.present?

    # Create a mock WRS for preview
    user = User.first || User.new(email: 'client@example.com', name: 'Test User', role: :client)
    building = Building.first || Building.new(name: 'Sample Building', street: '123 Main St', zipcode: 'SW1A 1AA')

    wrs = WindowScheduleRepair.new(
      user: user,
      building: building,
      name: 'Sample Window Repair',
      flat_number: '4A',
      reference_number: 'WRS-2024-001',
      slug: 'sample-wrs-slug',
      total_vat_included_price: '£1,250.00'
    )

    # Mock address method if building is present
    if building.present?
    end
    wrs.define_singleton_method(:address) { '123 Main Street' }

    wrs
  end

  def create_sample_invoice(_wrs)
    # Try to use existing invoice from database, otherwise create a mock
    invoice = Invoice.first

    return invoice if invoice.present?

    # Create a mock invoice for preview
    invoice = Invoice.new(
      slug: 'inv-2024-001',
      total_amount: 1250.00,
      flat_address: '123 Main Street, Flat 4A'
    )

    # Mock freshbooks_invoices association
    fb_invoice = OpenStruct.new(invoice_number: 'INV-2024-001')
    invoice.define_singleton_method(:freshbooks_invoices) do
      OpenStruct.new(last: fb_invoice)
    end

    invoice
  end
end
