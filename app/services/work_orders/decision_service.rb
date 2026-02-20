# frozen_string_literal: true

module WorkOrders
  # Handles client accept/decline decisions coming from the public work order page.
  # On accept:
  # - ensures a FreshBooks client exists
  # - creates a Rails Invoice linked to the work order
  # - marks work order as approved
  # - queues a background job to create FreshBooks invoice (responds immediately to client)
  #
  # On decline:
  # - notifies the admin
  # - updates the work order status
  class DecisionService < BaseService
    attribute :work_order
    attribute :first_name, :string
    attribute :last_name, :string
    attribute :email, :string
    attribute :decision, :string

    def call
      if work_order.nil?
        add_error('Work order is required')
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
        # Prevent duplicate decisions / invoice creation
        if work_order.work_order_decision.present?
          add_error('A decision has already been recorded for this work order.')
          return
        end

        # Create WorkOrderDecision first in its own transaction so it's never lost
        # even if later steps (invoice, background job) fail
        record_decision!('approved')

        ActiveRecord::Base.transaction do
          fb_client = ensure_freshbooks_client!
          invoice = create_local_invoice!(fb_client)
          mark_work_order_as_approved!

          # Queue FreshBooks invoice creation as background job (perform_later)
          queue_freshbooks_invoice_creation(invoice, fb_client)

          self.result = { invoice_id: invoice.id }
        end
      end
    end

    def handle_decline
      with_error_handling do
        if work_order.work_order_decision.present?
          add_error('A decision has already been recorded for this work order.')
          return
        end

        # Create WorkOrderDecision first in its own transaction so it's never lost
        record_decision!('rejected')

        ActiveRecord::Base.transaction do
          mark_work_order_as_rejected!
          send_admin_decline_email!
        end
      end
    end

    def record_decision!(resolved_decision)
      WorkOrderDecision.create!(
        work_order: work_order,
        decision: resolved_decision,
        decision_at: Time.current,
        client_email: email,
        client_name: "#{first_name} #{last_name}".strip,
        terms_accepted_at: resolved_decision == 'approved' ? Time.current : nil,
        decision_metadata: {
          ip: nil, # caller can enrich later if needed
          source: 'wrs_form'
        }
      )
    end

    def ensure_freshbooks_client!
      FreshbooksClientEnsurer.new(email, first_name, last_name, building).call
    end

    def create_local_invoice!(fb_client_data)
      fb_client_id = fb_client_data['id'] || fb_client_data['clientid']

      Invoice.create!(
        name: "Invoice #{work_order.name}",
        slug: generate_invoice_slug,
        job: work_order.name,
        freshbooks_client_id: fb_client_id,
        work_order_id: work_order.id,
        wrs_link: work_order_public_url,
        included_vat_amount: work_order.total_vat_included_price,
        excluded_vat_amount: work_order.total_vat_excluded_price,
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
          name: 'Flat | Work Order',
          description: "Visit #{work_order_public_url} to view the complete description of the items.",
          quantity: 1,
          cost: work_order.total_vat_included_price || 0,
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

    def mark_work_order_as_approved!
      work_order.update!(
        status: WorkOrder.statuses[:approved]
      )
    end

    def mark_work_order_as_rejected!
      work_order.update!(
        status: WorkOrder.statuses[:rejected]
      )
    end

    def send_admin_decline_email!
      email_notifier.send_decline_email
    end

    def email_notifier
      @email_notifier ||= EmailNotifier.new(work_order, first_name, last_name, email)
    end

    def work_order_public_url
      host = ENV.fetch('PUBLIC_APP_HOST', 'bulletservices.co.uk')
      "#{host}/wrs/#{work_order.slug}"
    end

    def building
      work_order.building
    end

    def primary_street
      building&.street
    end

    def flat_address
      [
        work_order.address,
        "Flat #{work_order.flat_number}"
      ].compact.join(', ')
    end

    def generate_invoice_slug
      base = "invoice-#{work_order.name}"
      base.parameterize
    end
  end
end
