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
        ActiveRecord::Base.transaction do
          fb_client = ensure_freshbooks_client!
          invoice = create_local_invoice!(fb_client)
          result = create_freshbooks_invoice!(invoice, fb_client)

          attach_pdf_to_invoice(invoice, result) if result.is_a?(Hash)

          mark_wrs_as_approved!
          send_admin_accept_email!(invoice, fb_client)
        end
      end
    end

    def attach_pdf_to_invoice(invoice, result)
      pdf_data = {
        base64: result[:pdf_base64],
        url: result[:pdf_url]
      }
      PdfAttachmentService.new(invoice, pdf_data).call if pdf_data[:base64].present? || pdf_data[:url].present?
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
          tax_included: true
        }
      ]

      invoice.create_in_freshbooks!(
        client_id: fb_client_id,
        lines: lines,
        send_email: false
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

    def send_admin_accept_email!(invoice, fb_client_data)
      email_notifier.send_accept_email(invoice, fb_client_data)
    end

    def send_admin_decline_email!
      email_notifier.send_decline_email
    end

    def email_notifier
      @email_notifier ||= EmailNotifier.new(window_schedule_repair, first_name, last_name, email)
    end

    def wrs_public_url
      require_relative '../../../lib/config_helper'
      host = ConfigHelper.get_config(
        key: :public_app_host,
        env_key: 'PUBLIC_APP_HOST',
        default: 'bulletservices.co.uk'
      )
      Rails.application.routes.url_helpers.wrs_show_url(
        slug: window_schedule_repair.slug,
        host: host
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

    def generate_invoice_slug
      base = "wrs-#{window_schedule_repair.reference_number}-#{Time.current.to_i}"
      base.parameterize
    end
  end
end
