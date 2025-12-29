# frozen_string_literal: true

module Freshbooks
  class CreateInvoiceJob < ApplicationJob
    queue_as :default

    retry_on FreshbooksError, wait: :exponentially_longer, attempts: 3
    discard_on ActiveRecord::RecordNotFound

    def perform(invoice_id, lines_data, client_info = {})
      invoice = Invoice.find(invoice_id)
      lines = deserialize_lines(lines_data)
      client_params = extract_client_params(client_info)

      fb_client_id = ensure_freshbooks_client(**client_params)
      return unless fb_client_id

      process_invoice_creation(invoice, fb_client_id, lines, client_params)
    end

    private

    def extract_client_params(client_info)
      {
        client_id: client_info[:client_id],
        first_name: client_info[:first_name],
        last_name: client_info[:last_name],
        email: client_info[:email],
        building_id: client_info[:building_id]
      }
    end

    def process_invoice_creation(invoice, fb_client_id, lines, client_params)
      update_invoice_client_id(invoice, fb_client_id)

      result = create_freshbooks_invoice(invoice, fb_client_id, lines)
      return unless result

      attach_pdf_to_invoice(invoice, result) if result.is_a?(Hash)
      send_admin_accept_email(
        invoice,
        fb_client_id,
        client_params[:first_name],
        client_params[:last_name],
        client_params[:email]
      )
    end

    def update_invoice_client_id(invoice, fb_client_id)
      return if invoice.freshbooks_client_id == fb_client_id

      invoice.update!(freshbooks_client_id: fb_client_id)
    end

    def ensure_freshbooks_client(client_id:, first_name:, last_name:, email:, building_id:)
      # Check local client record first (needed for validation)
      local_client = FreshbooksClient.find_by(email: email)

      # Validate provided client_id if present
      if client_id.present?
        validated_id = validate_client_id(client_id, email, local_client)
        return validated_id if validated_id.present?
      end

      # Check existing ID from local client
      existing_fb_id = extract_existing_freshbooks_id(local_client)

      # Validate existing ID if present
      if existing_fb_id.present?
        validated_id = validate_client_id(existing_fb_id, email, local_client)
        return validated_id if validated_id.present?
      end

      # Create new client if no valid ID found
      create_and_link_freshbooks_client(local_client, first_name, last_name, email, building_id)
    end

    def validate_client_id(client_id, email, local_client = nil)
      clients_service = Freshbooks::Clients.new
      client_data = clients_service.get(client_id)

      return client_id if client_data.present?

      clear_invalid_client_id(client_id, email, local_client)
      nil
    rescue FreshbooksError => e
      handle_validation_error(e, client_id, email, local_client)
    end

    def clear_invalid_client_id(client_id, email, local_client)
      return unless local_client&.freshbooks_id == client_id

      Rails.logger.warn(
        "Invalid FreshBooks client ID #{client_id} for email #{email}. " \
        'Clearing from local record and creating new client.'
      )
      local_client.update!(freshbooks_id: nil)
    end

    def handle_validation_error(error, client_id, email, local_client)
      if [404, 422].include?(error.status_code)
        handle_not_found_error(error, client_id, email, local_client)
        return nil
      end

      Rails.logger.error("Error validating FreshBooks client ID #{client_id}: #{error.message}")
      raise
    end

    def handle_not_found_error(error, client_id, email, local_client)
      Rails.logger.warn(
        "FreshBooks client ID #{client_id} not found or invalid for email #{email} " \
        "(status: #{error.status_code}). Clearing from local record and creating new client."
      )
      local_client&.update!(freshbooks_id: nil) if local_client&.freshbooks_id == client_id
    end

    def extract_existing_freshbooks_id(local_client)
      local_client&.freshbooks_id if local_client&.freshbooks_id.present?
    end

    def create_and_link_freshbooks_client(local_client, first_name, last_name, email, building_id)
      building = Building.find_by(id: building_id) if building_id.present?
      client_data = create_freshbooks_client(first_name, last_name, email, building)
      fb_id = extract_freshbooks_id(client_data)

      if local_client
        local_client.update!(freshbooks_id: fb_id)
        return local_client.freshbooks_id
      end

      fb_id
    end

    def create_freshbooks_client(first_name, last_name, email, building)
      params = build_client_params(first_name, last_name, email, building)
      created = Freshbooks::Clients.new.create(params)
      fb_id = extract_freshbooks_id(created)

      update_local_client_record(
        email: email,
        fb_id: fb_id,
        client_attrs: {
          first_name: first_name,
          last_name: last_name,
          building: building,
          created: created
        }
      )
      Rails.logger.info("Created FreshBooks client: #{fb_id} for email: #{email}")

      created
    end

    def build_client_params(first_name, last_name, email, building)
      {
        email: email,
        first_name: first_name,
        last_name: last_name,
        organization: nil,
        phone: nil,
        address: building&.street,
        city: 'London',
        province: nil,
        postal_code: building&.zipcode,
        country: building&.country || 'UK'
      }
    end

    def extract_freshbooks_id(created)
      created['id'] || created['clientid']
    end

    def update_local_client_record(email:, fb_id:, client_attrs:)
      local_client = FreshbooksClient.find_or_initialize_by(email: email)
      local_client.update!(
        freshbooks_id: fb_id,
        first_name: client_attrs[:first_name],
        last_name: client_attrs[:last_name],
        address: client_attrs[:building]&.street,
        city: 'London',
        postal_code: client_attrs[:building]&.zipcode,
        country: client_attrs[:building]&.country || 'UK',
        raw_data: client_attrs[:created]
      )
    end

    def create_freshbooks_invoice(invoice, client_id, lines)
      invoice.create_in_freshbooks!(
        client_id: client_id,
        lines: lines,
        send_email: false
      )
    rescue StandardError => e
      Rails.logger.error("Failed to create FreshBooks invoice for invoice #{invoice.id}: #{e.message}")
      raise
    end

    def attach_pdf_to_invoice(invoice, result)
      pdf_data = {
        base64: result[:pdf_base64],
        url: result[:pdf_url]
      }
      Wrs::PdfAttachmentService.new(invoice, pdf_data).call if pdf_data[:base64].present? || pdf_data[:url].present?
    rescue StandardError => e
      Rails.logger.error("Failed to attach PDF to invoice #{invoice.id}: #{e.message}")
      # Don't raise - PDF attachment failure shouldn't fail the job
    end

    def send_admin_accept_email(invoice, client_id, first_name, last_name, email)
      wrs = invoice.window_schedule_repair
      return unless wrs

      fb_client = FreshbooksClient.find_by(freshbooks_id: client_id)
      return unless fb_client

      client_attrs = extract_client_attributes_for_email(fb_client, first_name, last_name, email)
      client_data = build_client_data_for_email(client_id, client_attrs)
      send_email_notification(wrs, invoice, client_data, client_attrs)
    rescue StandardError => e
      Rails.logger.error("Failed to send admin accept email for invoice #{invoice.id}: #{e.message}")
      # Don't raise - email failure shouldn't fail the job
    end

    def extract_client_attributes_for_email(fb_client, first_name, last_name, email)
      {
        first_name: first_name || fb_client.first_name,
        last_name: last_name || fb_client.last_name,
        email: email || fb_client.email
      }
    end

    def build_client_data_for_email(client_id, client_attrs)
      {
        'id' => client_id,
        'email' => client_attrs[:email],
        'fname' => client_attrs[:first_name],
        'lname' => client_attrs[:last_name]
      }
    end

    def send_email_notification(wrs, invoice, client_data, client_attrs)
      Wrs::EmailNotifier.new(
        wrs,
        client_attrs[:first_name],
        client_attrs[:last_name],
        client_attrs[:email]
      ).send_accept_email(invoice, client_data)
    end

    def deserialize_lines(lines_data)
      return [] unless lines_data

      lines_data.is_a?(String) ? JSON.parse(lines_data) : lines_data
    end
  end
end
