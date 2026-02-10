# frozen_string_literal: true

module Wrs
  # Handles client accept/decline decisions coming from the public WRS page.
  # On accept:
  # - ensures a FreshBooks client exists
  # - creates a Rails Invoice linked to the WRS
  # - marks WRS as approved
  # - queues a background job to create FreshBooks invoice (responds immediately to client)
  #
  # The background job handles:
  # - creating the FreshBooks invoice
  # - mirroring the FreshBooks PDF into Active Storage
  # - notifying the admin
  #
  # On decline:
  # - notifies the admin
  # - updates the WRS status
  class DecisionService < BaseService
    attribute :window_schedule_repair
    attribute :first_name, :string
    attribute :last_name, :string
    attribute :email, :string
    attribute :decision, :string

    def call
      if window_schedule_repair.nil?
        add_error('WRS is required')
        return self
      end

      if decision.blank?
        add_error('Decision is required')
        return self
      end

      case decision.to_s
      when 'accept'
        handle_accept
      when 'decline'
        handle_decline
      else
        add_error('Invalid decision')
      end

      self
    end

    private

    def handle_accept
      with_error_handling do
        # Prevent duplicate invoice creation
        if window_schedule_repair.invoices.exists?
          add_error('An invoice already exists for this WRS. A decision has already been made.')
          return
        end

        ActiveRecord::Base.transaction do
          fb_client = ensure_freshbooks_client!
          invoice = create_local_invoice!(fb_client)
          mark_wrs_as_approved!

          # Queue FreshBooks invoice creation as background job
          # This ensures we respond to the client immediately without waiting for 3rd party API
          queue_freshbooks_invoice_creation(invoice, fb_client)

          self.result = { invoice_id: invoice.id }
        end
      end
    end

    def handle_decline
      with_error_handling do
        ActiveRecord::Base.transaction do
          mark_wrs_as_rejected!
          send_admin_decline_email!
        end
      end
    end

    def ensure_freshbooks_client!
      FreshbooksClientEnsurer.new(email, first_name, last_name, building).call
    end

    def create_local_invoice!(fb_client_data)
      fb_client_id = fb_client_data['id'] || fb_client_data['clientid']

      Invoice.create!(
        name: "Invoice #{window_schedule_repair.name}",
        slug: generate_invoice_slug,
        job: window_schedule_repair.name,
        freshbooks_client_id: fb_client_id,
        work_order_id: window_schedule_repair.id,
        wrs_link: wrs_public_url,
        included_vat_amount: window_schedule_repair.total_vat_included_price,
        excluded_vat_amount: window_schedule_repair.total_vat_excluded_price,
        status: 'draft',
        final_status: 'draft',
        flat_address: flat_address,
        generated_by: 'wrs_form'
      )
    end

    def queue_freshbooks_invoice_creation(invoice, fb_client_data)
      fb_client_id = fb_client_data['id'] || fb_client_data['clientid']

      lines = [
        {
          name: 'Flat | Windows Schedule Repairs',
          description: "Visit #{wrs_public_url} to view the complete description of the items.",
          quantity: 1,
          cost: window_schedule_repair.total_vat_included_price || 0,
          type: 0,
          tax_included: true
        }
      ]

      Freshbooks::CreateInvoiceJob.perform_later(
        invoice.id,
        lines,
        client_id: fb_client_id,
        first_name: first_name,
        last_name: last_name,
        email: email,
        building_id: building&.id
      )
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

    def send_admin_decline_email!
      email_notifier.send_decline_email
    end

    def email_notifier
      @email_notifier ||= EmailNotifier.new(window_schedule_repair, first_name, last_name, email)
    end

    def wrs_public_url
      host = ENV.fetch('PUBLIC_APP_HOST', 'bulletservices.co.uk')
      "#{host}/wrs/#{window_schedule_repair.slug}"
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

    def generate_invoice_slug
      base = "invoice-#{window_schedule_repair.name}"
      base.parameterize
    end
  end
end
